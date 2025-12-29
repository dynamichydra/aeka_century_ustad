import 'package:flutter/material.dart';
import '../../../../core/constants.dart';
import '../../domain/entities/onboarding_content.dart';
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingContent> _contents = [
    OnboardingContent(
      title: "Welcome to Century AI",
      description: "Experience the next generation of artificial intelligence assistants tailored for you.",
      image: "assets/images/onboarding_1.png", // Placeholder path
    ),
    OnboardingContent(
      title: "Smart Solutions",
      description: "Get smart solutions to your everyday problems with our advanced AI algorithms.",
      image: "assets/images/onboarding_2.png", // Placeholder path
    ),
    OnboardingContent(
      title: "Get Started",
      description: "Join us today and explore the limitless possibilities with Century AI.",
      image: "assets/images/onboarding_3.png", // Placeholder path
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (value) {
                  setState(() {
                    _currentPage = value;
                  });
                },
                itemCount: _contents.length,
                itemBuilder: (context, index) => OnboardingContentWidget(
                  content: _contents[index],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultPadding),
                child: Column(
                  children: [
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _contents.length,
                        (index) => buildDot(index: index),
                      ),
                    ),
                    const Spacer(flex: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentPage != _contents.length - 1)
                           TextButton(
                              onPressed: () {
                                _pageController.jumpToPage(_contents.length - 1);
                              },
                              child: const Text("SKIP"),
                            )
                        else
                          const SizedBox(width: 60), // Spacer for layout balance
                          
                        ElevatedButton(
                          onPressed: () {
                            if (_currentPage == _contents.length - 1) {
                              // Navigate to Home or Login
                              // Navigator.pushNamed(context, '/home');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Navigate to Home")),
                              );
                            } else {
                              _pageController.nextPage(
                                duration: AppConstants.defaultDuration,
                                curve: Curves.ease,
                              );
                            }
                          },
                          child: Text(
                            _currentPage == _contents.length - 1
                                ? "Get Started"
                                : "Next",
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AnimatedContainer buildDot({required int index}) {
    return AnimatedContainer(
      duration: AppConstants.defaultDuration,
      margin: const EdgeInsets.only(right: 5),
      height: 6,
      width: _currentPage == index ? 20 : 6,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? Theme.of(context).primaryColor
            : const Color(0xFFD8D8D8),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class OnboardingContentWidget extends StatelessWidget {
  final OnboardingContent content;
  const OnboardingContentWidget({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        // Check if image exists, otherwise icon placeholder
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
             color: Colors.grey.shade200,
             borderRadius: BorderRadius.circular(20)
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          child: const Icon(Icons.image, size: 100, color: Colors.grey),
          // child: Image.asset(content.image), 
        ),
        const Spacer(),
        Text(
          content.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
        ),
        const SizedBox(height: 16),
        Text(
          content.description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
        const Spacer(),
      ],
    );
  }
}
