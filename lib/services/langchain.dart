import 'dart:io';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AssistantRAG {
  late final ChatOpenAI llm;
  late final MemoryVectorStore vectorstore;
  late final dynamic summarizerPipeline;
  late final dynamic ragPipeline;

  AssistantRAG() {
    _initialize();
  }

  void _initialize() async {
    await dotenv.load(fileName: "assets/.env");
    // Initialize models
    llm = ChatOpenAI(
      apiKey: dotenv.env['OPENAI_API_KEY'],
    );
    final embeddings = OpenAIEmbeddings(
      apiKey: dotenv.env['OPENAI_API_KEY'],
    );

    // Vectorstore
    vectorstore = MemoryVectorStore(embeddings: embeddings);
    final retriever = vectorstore.asRetriever();

    // Prompt for summarizer
    final summarizerPrompt = PromptTemplate.fromTemplate('''
    You are a professional summarizer assisting with daily conversation recall. Your task is to create a clear, concise, and accurate summary of the provided conversation transcription for personal reflection and memory recall.

    Since the transcrption may contain irrelevant details, minor errors, or inaccuracies, focus on capturing the essential points and key discussions while removing redundant or incorrect information. Highlight key moments, topics discussed, and any decisions or action items mentioned.

    Key requirements:
    1. **Participants:** Mention the names of all individuals involved in the conversation, including myself if I participated.
    2. **Timestamps:** The transcription includes timestamps every 1 hour in the format DD MM YYYY HH:MM:SS. For every conversation, store the date and time of conversation. If the conversation spans multiple timestamps, store only starting date and time of conversation.
    3. **Accuracy:** Ensure the summary is short but reflects the true intent and flow of the conversation without distortion or omission of important details.

    The transcription is as follows: 

    conversation timestamp: {timestamp}\n
    {transcription}
    ''');

    // Pipeline for summarizer
    summarizerPipeline = summarizerPrompt.pipe(llm).pipe(StringOutputParser());

    // Pipeline for RAG
    final setupAndRetrieval = Runnable.fromMap<String>({
      'context': retriever.pipe(
        Runnable.mapInput((docs) => docs.map((d) => d.pageContent).join('\n')),
      ),
      'question': Runnable.passthrough(),
    });

    final ragPrompt = PromptTemplate.fromTemplate('''
    Answer the question based only on the following context. 
    Context: {context} 
    Question: {question}
    ''');

    ragPipeline =
        setupAndRetrieval.pipe(ragPrompt).pipe(llm).pipe(StringOutputParser());
  }

  Future<bool> addConversation(String filePath, String timestamp) async {
    try {
      // Open the file and read the contents
      final file = File(filePath);
      final transcription = file.readAsStringSync();

      // Generate a summary
      final summary = await summarizerPipeline.invoke({
        'transcription': transcription,
        'timestamp': timestamp,
      });

      // Create a document
      final doc = Document(
        pageContent: summary,
        metadata: {
          'timestamp': timestamp,
        },
      );
      // Add to vectorstore
      vectorstore.addDocuments(documents: [doc]);
    } catch (e) {
      print("============ Error in addConversation ============");
      print(e);
      return false;
    }
    return true;
  }

  Future<String> askQuestion(String question) async {
    print("===================\n In Ask Question \n ===================");
    // Retrieve the response
    try {
      final response = await ragPipeline.invoke(question);
      return response;
    } catch (e) {
      print("============ Error in askQuestion ============");
      print(e);
      return "Error in askQuestion";
    }
  }
}
