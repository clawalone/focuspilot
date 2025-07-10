class QuoteService {
  static final List<String> _quotes = [
    "The secret of getting ahead is getting started.",
    "It always seems impossible until it's done.",
    "Don't watch the clock; do what it does. Keep going.",
    "The future depends on what you do today.",
    "Believe you can and you're halfway there.",
    "Quality is not an act, it is a habit.",
    "Your focus determines your reality.",
    "Focus on being productive instead of busy.",
    "The only way to do great work is to love what you do.",
    "Small steps in the right direction can turn out to be the biggest step of your life.",
    "Productivity is never an accident. It is always the result of a commitment to excellence, intelligent planning, and focused effort.",
    "Starve your distractions, feed your focus.",
    "You don’t need more time, you need more focus.",
    "One day you will thank yourself for not giving up.",
    "Success is the sum of small efforts, repeated day in and day out.",
  ];

  static String getDailyQuote() {
    final dayOfYear = int.parse(
      "${DateTime.now().year}${DateTime.now().month}${DateTime.now().day}",
    );
    // Use the day as a seed to pick a quote, ensuring it rotates daily but stays same for the day
    final index = dayOfYear % _quotes.length;
    return _quotes[index];
  }
}
