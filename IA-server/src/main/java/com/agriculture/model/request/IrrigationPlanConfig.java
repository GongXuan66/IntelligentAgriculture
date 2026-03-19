package com.agriculture.model.request;

import lombok.Data;

/**
* 用于灌溉规划的请求端配置。
 * 这刻意轻量级且无状态，因此后端
 * 可以计算计划而不保留客户端偏好。
 */
@Data
public class IrrigationPlanConfig {
    private Boolean autoMode;
    private Integer moistureThreshold;
    private Integer minInterval; // seconds
}
