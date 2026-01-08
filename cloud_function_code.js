/**
 * MISSION REMINDER TRIGGER
 * 
 * Instructions:
 * 1. Initialize Firebase Functions in your project: `firebase init functions`
 * 2. Paste this code into `functions/index.js`
 * 3. Deploy: `firebase deploy --only functions`
 * 
 * This function runs every minute, checks for 'pending' missions that are due,
 * sends a push notification to the user's registered FCM token, and marks them as 'sent'.
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { initializeApp } = require("firebase-admin/app");

initializeApp();

exports.sendMissionReminders = onSchedule("every 1 minutes", async (event) => {
    const db = getFirestore();
    const messaging = getMessaging();
    const now = new Date();

    // Find missions that are due (or overdue) and still pending
    const snapshot = await db.collectionGroup('missions')
        .where('status', '==', 'pending')
        .where('reminderTime', '<=', now.toISOString())
        .limit(50) // Batching
        .get();

    if (snapshot.empty) return;

    const promises = snapshot.docs.map(async (doc) => {
        const mission = doc.data();
        const userDoc = await db.collection('users').doc(mission.userId).get();

        if (!userDoc.exists || !userDoc.data().fcmToken) {
            console.log(`No FCM token for user ${mission.userId}`);
            return doc.ref.update({ status: 'failed', error: 'no_token' });
        }

        const fcmToken = userDoc.data().fcmToken;

        const message = {
            token: fcmToken,
            data: {
                todoId: mission.id.toString(),
                title: mission.title,
                body: 'Action is required. Start your focus session now!',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            android: {
                priority: 'high',
                notification: {
                    channel_id: 'mission_channel', // Matches Android channel key
                }
            }
        };

        try {
            await messaging.send(message);
            return doc.ref.update({
                status: 'sent',
                sentAt: FieldValue.serverTimestamp()
            });
        } catch (error) {
            console.error(`Error sending mission ${mission.id}:`, error);
            return doc.ref.update({ status: 'error', error: error.message });
        }
    });

    await Promise.all(promises);
});
