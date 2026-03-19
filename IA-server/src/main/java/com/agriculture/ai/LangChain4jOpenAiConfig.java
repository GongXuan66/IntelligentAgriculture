//package com.agriculture.ai;
//
//import dev.langchain4j.http.client.HttpClientBuilder;
//import dev.langchain4j.model.chat.listener.ChatModelListener;
//import dev.langchain4j.model.openai.OpenAiStreamingChatModel;
//import dev.langchain4j.openai.spring.ChatModelProperties;
//import dev.langchain4j.openai.spring.Properties;
//import org.springframework.beans.factory.ObjectProvider;
//import org.springframework.beans.factory.annotation.Qualifier;
//import org.springframework.boot.context.properties.EnableConfigurationProperties;
//import org.springframework.context.annotation.Bean;
//import org.springframework.context.annotation.Configuration;
//import org.springframework.core.task.AsyncTaskExecutor;
//import org.springframework.web.client.RestClient;
//
//import java.util.List;
//
///**
// * LangChain4j OpenAI 自定义配置类
// * 支持灵活配置多个 StreamingChatModel 实例，适配智谱 GLM-5 等自定义端点
// */
//@Configuration
//@EnableConfigurationProperties(Properties.class) // 启用配置文件绑定
//public class LangChain4jOpenAiConfig {
//
//    // 自定义 Bean 名称常量（便于管理）
//    public static final String GLM5_STREAMING_CHAT_MODEL = "glm5StreamingChatModel";
//    public static final String GLM5_HTTP_CLIENT_BUILDER = "glm5HttpClientBuilder";
//    public static final String GLM5_TASK_EXECUTOR = "glm5TaskExecutor";
//
//    /**
//     * 构建智谱 GLM-5 专属的 StreamingChatModel
//     * 完全自定义配置，脱离自动配置的限制
//     */
//    @Bean(GLM5_STREAMING_CHAT_MODEL)
//    public OpenAiStreamingChatModel glm5StreamingChatModel(
//            @Qualifier(GLM5_HTTP_CLIENT_BUILDER) HttpClientBuilder httpClientBuilder,
//            Properties properties, // 绑定配置文件中的 langchain4j.open-ai 配置
//            ObjectProvider<ChatModelListener> chatModelListeners // 自动注入监听器
//    ) {
//        // 1. 从配置文件读取基础配置（也可完全硬编码或从自定义配置读取）
//        ChatModelProperties streamingChatModelProps = properties.streamingChatModel();
//
//        // 2. 构建自定义 StreamingChatModel
//        return OpenAiStreamingChatModel.builder()
//                // 核心配置（从配置文件读取）
//                .httpClientBuilder(httpClientBuilder)
//                .baseUrl(streamingChatModelProps.baseUrl())       // 智谱端点：https://api-inference.modelscope.cn/v1
//                .apiKey(streamingChatModelProps.apiKey())         // 你的 API Key
//                .modelName(streamingChatModelProps.modelName())   // ZhipuAI/GLM-5
//                // 可自定义的参数（按需调整）
//                .temperature(streamingChatModelProps.temperature() != null ?
//                        streamingChatModelProps.temperature() : 0.7) // 默认温度 0.7
//                .topP(streamingChatModelProps.topP() != null ?
//                        streamingChatModelProps.topP() : 1.0)
//                .maxTokens(streamingChatModelProps.maxTokens() != null ?
//                        streamingChatModelProps.maxTokens() : 4096)
//                .timeout(streamingChatModelProps.timeout() != null ?
//                        streamingChatModelProps.timeout() : java.time.Duration.ofMinutes(1))
//                // 日志配置
//                .logRequests(true)  // 开启请求日志
//                .logResponses(true) // 开启响应日志
//                // 监听器（自动注入）
//                .listeners(chatModelListeners.orderedStream().toList())
//                // 自定义扩展参数（智谱专属）
//                .customHeaders(streamingChatModelProps.customHeaders()) // 自定义请求头
//                .customQueryParams(streamingChatModelProps.customQueryParams()) // 自定义查询参数
//                // 智谱 GLM-5 专属配置（按需添加）
//                .user(streamingChatModelProps.user() != null ?
//                        streamingChatModelProps.user() : "langchain4j-user")
//                .strictTools(false) // 关闭严格工具调用（适配智谱）
//                .parallelToolCalls(true) // 开启并行工具调用
//                .build();
//    }
//
//    /**
//     * 构建智谱 GLM-5 专属的 HttpClientBuilder
//     * 复用 LangChain4j 自动配置的 RestClient 逻辑
//     */
//    @Bean(GLM5_HTTP_CLIENT_BUILDER)
//    public HttpClientBuilder glm5HttpClientBuilder(
//            ObjectProvider<RestClient.Builder> restClientBuilder,
//            @Qualifier(GLM5_TASK_EXECUTOR) AsyncTaskExecutor glm5TaskExecutor
//    ) {
//        // 使用 SpringRestClient 构建 HttpClient（与自动配置逻辑一致）
//        return dev.langchain4j.http.client.spring.restclient.SpringRestClient.builder()
//                .restClientBuilder(restClientBuilder.getIfAvailable(RestClient::builder))
//                .streamingRequestExecutor(glm5TaskExecutor) // 流式响应需要异步执行器
//                .createDefaultStreamingRequestExecutor(true);
//    }
//
//    /**
//     * 为智谱 GLM-5 流式模型创建专属的异步任务执行器
//     * 适配上下文传播（与自动配置逻辑对齐）
//     */
//    @Bean(GLM5_TASK_EXECUTOR)
//    public AsyncTaskExecutor glm5TaskExecutor() {
//        org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor executor =
//                new org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor();
//        // 核心线程池配置（按需调整）
//        executor.setCorePoolSize(5);
//        executor.setMaxPoolSize(10);
//        executor.setQueueCapacity(0); // 无队列，直接创建新线程（流式响应推荐）
//        executor.setThreadNamePrefix("LangChain4j-GLM5-"); // 线程名前缀（便于日志排查）
//
//        // 上下文传播（如果存在 micrometer 依赖）
//        try {
//            Class.forName("io.micrometer.context.ContextSnapshotFactory");
//            executor.setTaskDecorator(new org.springframework.core.task.support.ContextPropagatingTaskDecorator());
//        } catch (ClassNotFoundException e) {
//            // 无 micrometer 依赖时跳过上下文传播
//        }
//
//        executor.initialize(); // 初始化执行器
//        return executor;
//    }
//
//    // ========== 扩展：如需添加第二个模型（比如 OpenAI 原生 GPT-4o），直接新增 Bean 即可 ==========
//    public static final String GPT4O_STREAMING_CHAT_MODEL = "gpt4oStreamingChatModel";
//    public static final String GPT4O_HTTP_CLIENT_BUILDER = "gpt4oHttpClientBuilder";
//    public static final String GPT4O_TASK_EXECUTOR = "gpt4oTaskExecutor";
//
//    @Bean(GPT4O_STREAMING_CHAT_MODEL)
//    public OpenAiStreamingChatModel gpt4oStreamingChatModel(
//            @Qualifier(GPT4O_HTTP_CLIENT_BUILDER) HttpClientBuilder httpClientBuilder,
//            ObjectProvider<ChatModelListener> chatModelListeners
//    ) {
//        return OpenAiStreamingChatModel.builder()
//                .httpClientBuilder(httpClientBuilder)
//                .baseUrl("https://api.openai.com/v1") // OpenAI 原生端点
//                .apiKey("你的 GPT-4o API Key") // 可从配置文件读取
//                .modelName("gpt-4o")
//                .temperature(0.5)
//                .maxTokens(8192)
//                .logRequests(true)
//                .logResponses(true)
//                .listeners(chatModelListeners.orderedStream().toList())
//                .build();
//    }
//
//    @Bean(GPT4O_HTTP_CLIENT_BUILDER)
//    public HttpClientBuilder gpt4oHttpClientBuilder(
//            ObjectProvider<RestClient.Builder> restClientBuilder,
//            @Qualifier(GPT4O_TASK_EXECUTOR) AsyncTaskExecutor gpt4oTaskExecutor
//    ) {
//        return dev.langchain4j.http.client.spring.restclient.SpringRestClient.builder()
//                .restClientBuilder(restClientBuilder.getIfAvailable(RestClient::builder))
//                .streamingRequestExecutor(gpt4oTaskExecutor)
//                .createDefaultStreamingRequestExecutor(true);
//    }
//
//    @Bean(GPT4O_TASK_EXECUTOR)
//    public AsyncTaskExecutor gpt4oTaskExecutor() {
//        org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor executor =
//                new org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor();
//        executor.setCorePoolSize(5);
//        executor.setMaxPoolSize(10);
//        executor.setQueueCapacity(0);
//        executor.setThreadNamePrefix("LangChain4j-GPT4o-");
//        try {
//            Class.forName("io.micrometer.context.ContextSnapshotFactory");
//            executor.setTaskDecorator(new org.springframework.core.task.support.ContextPropagatingTaskDecorator());
//        } catch (ClassNotFoundException e) {}
//        executor.initialize();
//        return executor;
//    }
//}
