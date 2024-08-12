import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, rootBundle;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';

Future<Map<String, String>> loadDotEnv() async {
  final String data = await rootBundle.loadString('.env');
  final Map<String, String> env = {};
  final List<String> lines = LineSplitter().convert(data);
  for (final line in lines) {
    final parts = line.split('=');
    if (parts.length >= 2) {
      final key = parts[0].trim();
      final value = parts.sublist(1).join('=').trim();
      env[key] = value;
    }
  }
  return env;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final Map<String, String> env = await loadDotEnv();
    final String? apiKey = env['API_KEY'];

    if (apiKey == null) {
      print('Error: API key no encontrada en el archivo .env');
      return;
    }

    runApp(MyApp(apiKey: apiKey));
  } catch (e) {
    print('Error al cargar el archivo .env: $e');
  }
}

class MyApp extends StatefulWidget {
  final String apiKey;

  const MyApp({Key? key, required this.apiKey}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en'); // Default to English

  void _setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BRIAN',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      locale: _locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('es', ''),
      ],
      home: SplashScreen(apiKey: widget.apiKey, setLocale: _setLocale),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final String apiKey;
  final ValueSetter<Locale> setLocale;

  const SplashScreen({Key? key, required this.apiKey, required this.setLocale})
      : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 3), () {});
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MyHomePage(apiKey: widget.apiKey, setLocale: widget.setLocale),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Lottie.asset('assets/animations/Intro.json'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String apiKey;
  final ValueSetter<Locale> setLocale;

  const MyHomePage({Key? key, required this.apiKey, required this.setLocale})
      : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late GenerativeModel model;
  String generatedText = '';
  TextEditingController textController = TextEditingController();
  File? selectedImage;
  bool showResponseOnly = false;
  bool isLoading = false;
  bool showAnimation = true;
  String? selectedCategory;
  String? selectedPromptType;
  String selectedPrompt = '';
  bool _buttonsEnabled = true;
  bool _isLanguageButtonEnabled = true;
  List<String> languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Portuguese',
    'Italian',
    'Russian',
    'Chinese',
    'Japanese',
    'Korean',
  ];
  String sourceLanguage = 'Spanish';
  String targetLanguage = 'English';

  // English Prompts
  final Map<String, Map<String, String>> promptOptionsEnglish = {
    'Answers with Explanation': {
      'Mathematics':
          'Solve the following math problems and explain your reasoning step by step. If you have options, then explain step by step until you provide the correct one. IT HAS TO MATCH one of the provided options (it has to match at least one). (Respond in English): ',
      'Science':
          'Answer the following natural science questions and explain your answer(Always respond in English regardless of the language in the image): ',
      'Theoretical Physics':
          'Answer the following theoretical physics questions and explain your answer(Always respond in English regardless of the language in the image): ',
      'Physics Exercise':
          'Solve the following physics exercises and explain your procedure(Always respond in English regardless of the language in the image): ',
      'Theoretical Chemistry':
          'Answer the following theoretical chemistry questions and explain your answer(Always respond in English regardless of the language in the image): ',
      'Chemistry Exercise':
          'In english Solve the following chemistry exercises and explain your procedure(Always respond in English regardless of the language in the image): ',
      'Language':
          '"Answer the following language and literature questions and explain your answer. (Always respond in English regardless of the language in the image)."',
      'Social History':
          'Answer the following social history questions and explain your answer(Always respond in English regardless of the language in the image): ',
      'Computer Science':
          'Answer the following computer science questions and explain your answer(Always respond in English regardless of the language in the image): ',
      'English Grammar':
          'Answer the following English grammar questions and explain your answer(Always respond in English regardless of the language in the image): '
    },
    'Open Answers': {
      'Mathematics':
          'Answer all the following math questions or exercises (Always respond in English regardless of the language in the image).',
      'Science':
          'Answer the following open-ended questions or natural science activities (Always respond in English regardless of the language in the image).',
      'Theoretical Physics':
          'Answer the following open-ended questions or theoretical physics exercises (Always respond in English regardless of the language in the image).',
      'Physics Exercise':
          'Solve the following physics exercises and answer the questions (Always respond in English regardless of the language in the image).',
      'Theoretical Chemistry':
          'Answer the following open-ended questions or theoretical chemistry exercises (Always respond in English regardless of the language in the image).',
      'Chemistry Exercise':
          'Solve the following chemistry exercises or problems and answer the questions (Always respond in English regardless of the language in the image).',
      'Language':
          'Answer the following open-ended language and literature questions or exercises (Always respond in English regardless of the language in the image).',
      'Language Summary':
          'Generate a summary for the following language and literature topic. If there are questions, answer them; if not, just provide the summary (Always respond in English regardless of the language in the image).',
      'Social History':
          'Answer the following open-ended questions or social history exercises (Always respond in English regardless of the language in the image).',
      'Social History Summary':
          'Generate a summary for the following social history topic. If there are questions, answer them; if not, just provide the summary (Always respond in English regardless of the language in the image).',
      'Computer Science':
          'Answer the following open-ended questions or computer science exercises (Always respond in English regardless of the language in the image).',
      'English Grammar':
          'Answer the following open-ended questions or exercises on English grammar (Always respond in English regardless of the language in the image).'
    },
    'Quick Answers': {
      'Multiple Choice A B C':
          'Quickly analyze the following questions and give me ONLY the correct letter with its respective question number without explanations(Answer in english): ',
      'Concept-Meaning Union':
          'Match the meaning with its respective correct option and give me the ordered answers(Answer in english): ',
      'Generate practice questions':
          'Generate a questionnaire with questions and answers about the following topic or text(Answer in english): ',
      'True/False Selection':
          'Indicate whether the following statements are True or False(Answer in english): ',
      'Fill in the Blank':
          'Complete the following sentences with the correct word or phrase(Answer in english): ',
      'Best Option Selection':
          'Give me the correct option for each of the following questions. If they have a number, use its correlative to give me the answers to the following questions(Answer in english): ',
      'Extract Main Ideas':
          'Extract the main ideas from the following text in an orderly manner(Answer in english): ',
      'Sentence unscrambling':
          'Order the following elements according to their correct sequence(Answer in english): ',
      'Translate':
          'Translate this image from {sourceLanguage} to {targetLanguage}, just TRANSLATE it: ',
    },
    'Answers with Explanation for Kids': {
      'Mathematics':
          'Solve the following math problems and explain your reasoning in a simple way with creative examples FOR KIDS (Always respond in English regardless of the language in the image)(You can use emojis to make it more engaging).',
      'Science':
          'Answer the following natural science questions and explain your answer with creative examples FOR KIDS (Always respond in English regardless of the language in the image(You can use emojis to make it more engaging)).',
      'Theoretical Physics':
          'Answer the following theoretical physics questions and explain your answer in a way that a child can understand with creative examples FOR KIDS (Always respond in English regardless of the language in the image)(You can use emojis to make it more engaging).',
      'Physics Exercise':
          'Solve the following physics exercises and explain your procedure step by step for kids with creative examples FOR KIDS (Always respond in English regardless of the language in the image)(You can use emojis to make it more engaging).',
      'Theoretical Chemistry':
          'Answer the following theoretical chemistry questions and explain your answer using creative examples FOR KIDS (Always respond in English regardless of the language in the image)(You can use emojis to make it more engaging).',
      'Chemistry Exercise':
          'Solve the following chemistry exercises and explain your procedure clearly or with examples creative FOR KIDS (Always respond in English regardless of the language in the image)(You can use emojis to make it more engaging).',
      'Language':
          'Answer the following language questions and explain your answer with simple examples for kids (Always respond in English regardless of the language in the image)(You can use emojis to make it more engaging).',
      'Social History':
          'Answer the following social history questions and explain your answer with easy-to-understand examples for kids (Always respond in English regardless of the language in the image)(You can use emojis to make it more engaging).',
      'Computer Science':
          'Answer the following computer science questions and explain your answer using simple examples for kids (Always respond in English regardless of the language in the image)(You can use emojis to make it more engaging).',
      'English Grammar':
          'Answer the following English grammar questions and explain your answer with simple examples for kids (Always respond in English regardless of the language in the image)(You can use emojis to make it more engaging).'
    },
  };

  // Spanish Prompts
  final Map<String, Map<String, String>> promptOptionsSpanish = {
    'Respuestas con explicación': {
      'Matemáticas':
          'Resuelve los siguientes problemas matemáticos y explica tu razonamiento paso a paso ,si tienes opciones entonces me explicas paso a paso hasta darme la correcta TIENE QUE COINCIDIR CON una de las proporcionadas(tiene que coincidir con al menos una)(Responde en español): ',
      'Ciencias':
          'Responde las siguientes preguntas de ciencias naturales y explica tu respuesta(Responde en español): ',
      'Física teórica':
          'Responde las siguientes preguntas de física teórica y explica tu respuesta(Responde en español): ',
      'Física ejercicio':
          'Resuelve los siguientes ejercicios de física y explica tu procedimiento(Responde en español): ',
      'Química teórica':
          'Responde las siguientes preguntas de química teórica y explica tu respuesta(Responde en español): ',
      'Química ejercicio':
          'Resuelve los siguientes ejercicios de química y explica tu procedimiento(Responde en español): ',
      'Lenguaje':
          'Responde las siguientes preguntas de lenguaje y literatura y explica tu respuesta(Responde en español): ',
      'Historia social':
          'Responde las siguientes preguntas de historia social y explica tu respuesta(Responde en español): ',
      'Informática':
          'Responde las siguientes preguntas de informática y explica tu respuesta(Responde en español): ',
      'Gramática Inglés':
          'Responde las siguientes preguntas de gramática en inglés y explica tu respuesta(Responde en español): '
    },
    'Respuestas abiertas': {
      'Matemáticas':
          'Responde todas las siguientes preguntas o ejercicios de matemáticas(Responde en español): ',
      'Ciencias':
          'Responde las siguientes preguntas abiertas o actividades de ciencias naturales(Responde en español): ',
      'Física teórica':
          'Responde las siguientes preguntas abiertas o ejercicios de física teórica(Responde en español): ',
      'Física ejercicio':
          'Resuelve los siguientes ejercicios de física y responde las preguntas(Responde en español): ',
      'Química teórica':
          'Responde las siguientes preguntas abiertas o ejercicios de química teórica(Responde en español): ',
      'Química ejercicio':
          'Resuelve los siguientes ejercicios de química o ejercicios y responde las preguntas(Responde en español): ',
      'Lenguaje':
          'Responde las siguientes preguntas o ejercicios abiertas de lenguaje y literatura(Responde en español): ',
      'Resumen lenguaje':
          'Genera un resumen para el siguiente tema de lenguaje y literatura ,si tiene preguntas respondelas sino solo haz el resumen(Responde en español): ',
      'Historia social':
          'Responde las siguientes preguntas abiertas o ejercicios de historia social(Responde en español): ',
      'Resumen historial social':
          'Genera un resumen para el siguiente tema de historia social ,si tiene preguntas respondelas sino solo haz el resumen(Responde en español): ',
      'Informática':
          'Responde las siguientes preguntas abiertas o ejercicios de informática(Responde en español): ',
      'Gramática Inglés':
          'Responde las siguientes preguntas abiertas o ejercicios de gramática en inglés(Responde en español): '
    },
    'Respuestas rápidas': {
      'Multiopción A B C':
          'Analiza rápido las siguientes preguntas y dame SOLO la literal correcta con su respectivo número de pregunta sin explicaciones: ',
      'Unión de Concepto-Significado':
          'Une el significado con su respectiva opción correcta y dame las respuestas ordenadas(Responde en español): ',
      'Generar cuestionario':
          'Genera un cuestionario con preguntas y respuestas sobre el siguiente tema o texto(Responde en español): ',
      'Selección de Verdadero/Falso':
          'Indica si las siguientes afirmaciónes son Verdaderas o Falsas(Responde en español): ',
      'Completa el Espacio':
          'Completa las siguientes frases con la palabra o frase correcta(Responde en español): ',
      'Selección de Mejor Opción':
          'Dame la opción correcta para cada una de las siguientes preguntas si tienen numero usa su correlativo para darme las respuestas de las siguientes preguntas(Responde en español): ',
      'Extraer ideas principales':
          'Extrae de forma ordenada las ideas principales del siguiente texto(Responde en español): ',
      'Ordenar elementos':
          'Ordena los siguientes elementos de acuerdo a su correcta secuencia(Responde en español): ',
      'Traducir':
          'Traduce esta imagen del {sourceLanguage} al {targetLanguage} solo TRADUCELO: ',
    },
    'Respuestas con explicacion para niños': {
      'Matemáticas':
          'Resuelve los siguientes problemas matemáticos y explica tu razonamiento de manera sencilla con ejemplos PARA NIÑOS(puedes usar emojis para ser mas llamativo)(Responde en español): ',
      'Ciencias':
          'Responde las siguientes preguntas de ciencias naturales y explica tu respuesta con ejemplos PARA NIÑOS(puedes usar emojis para ser mas llamativo)(Responde en español): ',
      'Física teórica':
          'Responde las siguientes preguntas de física teórica y explica tu respuesta de forma que un niño pueda entender con ejemplos PARA NIÑOS(puedes usar emojis para ser mas llamativo)(Responde en español): ',
      'Física ejercicio':
          'Resuelve los siguientes ejercicios de física y explica tu procedimiento paso a paso para niños con ejemplos PARA NIÑOS(puedes usar emojis para ser mas llamativo)(Responde en español): ',
      'Química teórica':
          'Responde las siguientes preguntas de química teórica y explica tu respuesta usando con ejemplos PARA NIÑOS(puedes usar emojis para ser mas llamativo)(Responde en español): ',
      'Química ejercicio':
          'Resuelve los siguientes ejercicios de química y explica tu procedimiento con claridad o con ejemplos PARA NIÑOS(puedes usar emojis para ser mas llamativo)(Responde en español): ',
      'Lenguaje':
          'Responde las siguientes preguntas de lenguaje y explica tu respuesta con ejemplos simples para niños(puedes usar emojis para ser mas llamativo)(Responde en español): ',
      'Historia social':
          'Responde las siguientes preguntas de historia social y explica tu respuesta con ejemplos fáciles de entender para niños(puedes usar emojis para ser mas llamativo)(Responde en español): ',
      'Informática':
          'Responde las siguientes preguntas de informática y explica tu respuesta usando ejemplos sencillos para niños(puedes usar emojis para ser mas llamativo)(Responde en español): ',
      'Gramática Inglés':
          'Responde las siguientes preguntas de gramática en inglés y explica tu respuesta con ejemplos simples para niños(puedes usar emojis para ser mas llamativo)(Responde en español): '
    },
  };

  @override
  void initState() {
    super.initState();

    final generationConfig =
        GenerationConfig(temperature: 0.5, topK: null, topP: null);

    model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: widget.apiKey,
      generationConfig: generationConfig,
      systemInstruction: Content.text(
          'Te llamas Brian, eres un asistente bilingue de estudio de todo tipo segun lo indique el usuario,contestaras de forma acertada ,rapida y amable.Si no entiendes algo pide de nuevo la imagen.Si la imagen esta en otro idioma la traduces para ti y respondes en el idioma que te pida el usuario en su indicacion(NUNCA pediras la imagen en otro idioma tu la leeras tal cual esta sin importar el idioma de la imagen).Tus respuestas tienen que ser en un formato ordenado(Preguntas centradas y respuesta alineadas a la izquierda).Te pueden preguntar lo mismo muchas veces pero NUNCA marcaras RECITATION error en tus respuestas'),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );

    // Reiniciar valores al navegar a esta pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetDropdownValues();
    });
  }

  void _resetDropdownValues() {
    setState(() {
      selectedCategory = null;
      selectedPromptType = null;
      selectedPrompt = '';
      selectedImage = null;
      showAnimation = true;
      showResponseOnly = false;
      isLoading = false;
    });
  }

  Future<void> generateText() async {
    setState(() {
      isLoading = true;
    });

    final content = [Content.text(selectedPrompt)];
    final response = await model.generateContent(content);
    setState(() {
      generatedText = cleanText(response.text ?? 'No se pudo generar texto');
      showResponseOnly = true;
      isLoading = false;
      showAnimation = false;
    });
  }

  Future<void> generateTextFromImageAndText() async {
    setState(() {
      _buttonsEnabled = false;
      _isLanguageButtonEnabled = false;
      isLoading = true;
      showAnimation = false;
    });

    if (selectedImage == null) {
      setState(() {
        generatedText = AppLocalizations.of(context)!.pleaseSelectAnImage;
        isLoading = false;
        _buttonsEnabled = true;
        _isLanguageButtonEnabled = true;
      });
      return;
    }

    final List<Uint8List> images = await Future.wait([
      selectedImage!.readAsBytes().then((value) => Uint8List.fromList(value)),
    ]);
    final imageParts = [
      DataPart('image/jpeg', images[0]),
    ];
    String? responseText;

    int retryCount = 0;
    const int maxRetries = 5; // Limite de reintentos

    do {
      try {
        final response = await model.generateContent([
          Content.multi([
            TextPart(selectedCategory ==
                        AppLocalizations.of(context)!.quickAnswers &&
                    selectedPromptType ==
                        AppLocalizations.of(context)!.translate
                ? selectedPrompt
                    .replaceAll('{sourceLanguage}', sourceLanguage)
                    .replaceAll('{targetLanguage}', targetLanguage)
                : selectedPrompt),
            ...imageParts
          ])
        ]);

        responseText = response.text;

        if (responseText == null) {
          await Future.delayed(const Duration(seconds: 1));
          responseText = response.text;
        }
      } on GenerativeAIException catch (e) {
        if (e.toString().contains('Candidate was blocked due to recitation')) {
          print('Error de recitación detectado. Reintentando...');
          retryCount++;
          await Future.delayed(const Duration(seconds: 1));
          continue;
        } else {
          rethrow;
        }
      } catch (e) {
        rethrow;
      }
    } while (responseText == null && retryCount < maxRetries);

    if (responseText == null) {
      setState(() {
        generatedText =
            "La imagen no concuerda con la categoria o no es muy clara por favor selecciona otra imagen";
        isLoading = false;
        _buttonsEnabled = true;
        _isLanguageButtonEnabled = true;
      });

      // Regresar al home después de 2 segundos
      Future.delayed(const Duration(seconds: 2), () {
        _resetDropdownValues();
      });

      return;
    }

    setState(() {
      generatedText = cleanText(responseText!);
      showResponseOnly = true;
      isLoading = false;
      showAnimation = false;
      _buttonsEnabled = true;
      _isLanguageButtonEnabled = true;
    });
  }

  String cleanText(String text) {
    String cleanedText = text.replaceAll(RegExp(r'\*\*|__|##|```'), '').trim();
    return cleanedText;
  }

  Future<void> pickImage(ImageSource source) async {
    final image = await ImagePicker().pickImage(source: source);
    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
      });
    }
  }

  void _changeLanguageAndReset() {
    widget.setLocale(Localizations.localeOf(context).languageCode == 'en'
        ? const Locale('es')
        : const Locale('en'));
    _resetDropdownValues();
  }

  @override
  Widget build(BuildContext context) {
    bool isSendButtonEnabled = selectedCategory != null &&
        selectedPromptType != null &&
        selectedImage != null;

    var promptOptions = Localizations.localeOf(context).languageCode == 'en'
        ? promptOptionsEnglish
        : promptOptionsSpanish;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'B',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF008645),
                  ),
                ),
                TextSpan(
                  text: 'R',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0E57E5),
                  ),
                ),
                TextSpan(
                  text: 'I',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFD700),
                    shadows: [
                      Shadow(
                        color:
                            const Color.fromARGB(255, 0, 0, 0).withOpacity(0.6),
                        offset: const Offset(2, 2),
                        blurRadius: 3.0,
                      ),
                    ],
                  ),
                ),
                TextSpan(
                  text: 'A',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFD700),
                    shadows: [
                      Shadow(
                        color:
                            const Color.fromARGB(255, 0, 0, 0).withOpacity(0.6),
                        offset: const Offset(2, 2),
                        blurRadius: 3.0,
                      ),
                    ],
                  ),
                ),
                TextSpan(
                  text: 'N',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD62D20),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (!showResponseOnly)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed:
                    _isLanguageButtonEnabled ? _changeLanguageAndReset : null,
                child: Text(Localizations.localeOf(context).languageCode == 'en'
                    ? 'EN'
                    : 'ES'),
              ),
            ),
          if (showResponseOnly)
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                _resetDropdownValues();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (showAnimation)
                      Lottie.asset('assets/animations/Stand.json',
                          width: 200, height: 200),
                    Text(
                      AppLocalizations.of(context)!.solveYourTest,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!showResponseOnly) ...[
                      DropdownButton<String>(
                        value: selectedCategory,
                        hint:
                            Text(AppLocalizations.of(context)!.selectCategory),
                        items: promptOptions.keys.map((String key) {
                          return DropdownMenuItem<String>(
                            value: key,
                            child: Text(key),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedCategory = newValue;
                            selectedPromptType = null;
                            selectedPrompt = '';
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      if (selectedCategory != null)
                        DropdownButton<String>(
                          value: selectedPromptType,
                          hint: Text(AppLocalizations.of(context)!.selectGenre),
                          items: promptOptions[selectedCategory]!
                              .keys
                              .map((String key) {
                            return DropdownMenuItem<String>(
                              value: key,
                              child: Text(key),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedPromptType = newValue!;
                              selectedPrompt =
                                  promptOptions[selectedCategory]![newValue]!;
                            });
                          },
                        ),
                      const SizedBox(height: 10),
                      if (selectedCategory ==
                              AppLocalizations.of(context)!.quickAnswers &&
                          selectedPromptType ==
                              AppLocalizations.of(context)!.translate) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            DropdownButton<String>(
                              value: sourceLanguage,
                              hint: Text(
                                  AppLocalizations.of(context)!.sourceLanguage),
                              items: languages
                                  .where(
                                      (language) => language != targetLanguage)
                                  .map((String language) {
                                return DropdownMenuItem<String>(
                                  value: language,
                                  child: Text(language),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  sourceLanguage = newValue!;
                                });
                              },
                            ),
                            DropdownButton<String>(
                              value: targetLanguage,
                              hint: Text(
                                  AppLocalizations.of(context)!.targetLanguage),
                              items: languages
                                  .where(
                                      (language) => language != sourceLanguage)
                                  .map((String language) {
                                return DropdownMenuItem<String>(
                                  value: language,
                                  child: Text(language),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  targetLanguage = newValue!;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _buttonsEnabled
                                ? () => pickImage(ImageSource.gallery)
                                : null,
                            child:
                                Text(AppLocalizations.of(context)!.selectImage),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _buttonsEnabled
                                ? () => pickImage(ImageSource.camera)
                                : null,
                            child:
                                Text(AppLocalizations.of(context)!.takePhoto),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                        ),
                        child: selectedImage != null
                            ? Image.file(selectedImage!, fit: BoxFit.cover)
                            : Center(
                                child: Text(AppLocalizations.of(context)!
                                    .noImageSelected),
                              ),
                      ),
                    ],
                    if (isLoading)
                      Lottie.asset('assets/animations/Loading.json',
                          width: 150, height: 150),
                    if (!isLoading && showResponseOnly)
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.8,
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey),
                              ),
                              child: SingleChildScrollView(
                                child: Text(
                                  generatedText,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy),
                                      onPressed: () {
                                        Clipboard.setData(
                                            ClipboardData(text: generatedText));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    AppLocalizations.of(
                                                            context)!
                                                        .textCopied)));
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.share),
                                      onPressed: () {
                                        Share.share(generatedText,
                                            subject:
                                                AppLocalizations.of(context)!
                                                    .brianResponse);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (!showResponseOnly && !isLoading)
                      ElevatedButton(
                        onPressed: isSendButtonEnabled
                            ? generateTextFromImageAndText
                            : null,
                        child: Text(AppLocalizations.of(context)!.send),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
