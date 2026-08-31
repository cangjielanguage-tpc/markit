package fswatch.tests.unit.core

/* cjlint-ignore -start !G.PKG.01 */
import std.unittest.*
import std.unittest.testmacro.*
/* cjlint-ignore -end */
import fswatch.core.{MonitorConfig, LogLevel}
import fswatch.backends.BackendType

/**
 * MonitorConfig单元测试
 * 测试监听器配置的功能
 */
@Test
@Tag[UnitTest, Core, MonitorConfig]
class TestMonitorConfig {
    
    /**
     * 测试默认配置创建
     */
    @TestCase
    func testDefaultConfig() {
        let config = MonitorConfig.default()
        
        @Expect(config.backendType.toString(), "BackendType.Auto")
        @Expect(config.pollInterval, 1000)
        @Expect(config.maxRecursiveDepth, 10)
        @Expect(config.enableVerboseLogging, false)
        @Expect(config.enablePerformanceMonitoring, false)
        @Expect(config.enableErrorRecovery, true)
        @Expect(config.maxRetryAttempts, 3)
        @Expect(config.retryIntervalMs, 1000)
        @Expect(config.performanceReportIntervalMs, 300000)
    }
    
    /**
     * 测试配置克隆
     */
    @TestCase
    func testConfigClone() {
        let original = MonitorConfig.default()
        let cloned = original.clone()
        
        @Expect(cloned.backendType.toString(), original.backendType.toString())
        @Expect(cloned.pollInterval, original.pollInterval)
        @Expect(cloned.maxRecursiveDepth, original.maxRecursiveDepth)
        @Expect(cloned.enableVerboseLogging, original.enableVerboseLogging)
        @Expect(cloned.enablePerformanceMonitoring, original.enablePerformanceMonitoring)
        @Expect(cloned.enableErrorRecovery, original.enableErrorRecovery)
        @Expect(cloned.maxRetryAttempts, original.maxRetryAttempts)
        @Expect(cloned.retryIntervalMs, original.retryIntervalMs)
        @Expect(cloned.performanceReportIntervalMs, original.performanceReportIntervalMs)
    }
    
    /**
     * 测试配置验证 - 有效配置
     */
    @TestCase
    func testValidConfigValidation() {
        let config = MonitorConfig.default()
        let errors = config.validate()
        
        @Expect(errors.isEmpty(), true)
    }
    
    /**
     * 测试配置验证 - 无效轮询间隔
     */
    @TestCase
    func testInvalidPollIntervalValidation() {
        let config = MonitorConfig.default()
        config.pollInterval = 5  // 无效值，小于10ms
        
        let errors = config.validate()
        @Expect(errors.isEmpty(), false)
        @Expect(errors.size >= 1, true)
    }
    
    /**
     * 测试配置验证 - 无效递归深度
     */
    @TestCase
    func testInvalidRecursiveDepthValidation() {
        let config = MonitorConfig.default()
        config.maxRecursiveDepth = -1  // 无效值
        
        let errors = config.validate()
        @Expect(errors.isEmpty(), false)
        @Expect(errors.size >= 1, true)
    }
    
    /**
     * 测试配置验证 - 无效重试次数
     */
    @TestCase
    func testInvalidRetryAttemptsValidation() {
        let config = MonitorConfig.default()
        config.maxRetryAttempts = -1  // 无效值
        
        let errors = config.validate()
        @Expect(errors.isEmpty(), false)
        @Expect(errors.size >= 1, true)
    }
    
    /**
     * 测试高性能配置
     */
    @TestCase
    func testHighPerformanceConfig() {
        let config = MonitorConfig.highPerformance()
        
        @Expect(config.backendType.toString(), "BackendType.Native")
        @Expect(config.enableBatchProcessing, true)
        @Expect(config.batchSize, 500)
        @Expect(config.enablePerformanceMonitoring, true)
    }
    
    /**
     * 测试低资源配置
     */
    @TestCase
    func testLowResourceConfig() {
        let config = MonitorConfig.lowResource()
        
        @Expect(config.backendType.toString(), "BackendType.Polling")
        @Expect(config.pollInterval, 2000)
        @Expect(config.enableBatchProcessing, false)
        @Expect(config.enablePerformanceMonitoring, false)
    }
    
    /**
     * 测试调试配置
     */
    @TestCase
    func testDebugConfig() {
        let config = MonitorConfig.debug()
        
        @Expect(config.enableVerboseLogging, true)
        @Expect(config.logLevel.toString(), "LogLevel.Debug")
        @Expect(config.enablePerformanceMonitoring, true)
        @Expect(config.enableErrorRecovery, true)
    }
    
    /**
     * 测试配置ToString
     */
    @TestCase
    func testConfigToString() {
        let config = MonitorConfig.default()
        let configStr = config.toString()
        
        @Expect(configStr.contains("MonitorConfig"), true)
        @Expect(configStr.contains("backendType"), true)
        @Expect(configStr.contains("pollInterval"), true)
    }
}