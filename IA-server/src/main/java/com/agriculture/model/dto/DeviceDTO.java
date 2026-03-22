package com.agriculture.model.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 设备DTO
 */
@Data
public class DeviceDTO {

    private Long id;
    private Long pointId;
    private String deviceCode;
    private String deviceName;
    private String deviceType;
    private String deviceModel;
    private String manufacturer;
    private Integer status;
    private LocalDateTime lastHeartbeat;
    private LocalDateTime installedAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    @Data
    public static class CreateRequest {
        @NotBlank(message = "检测点ID不能为空")
        private Long pointId;

        @NotBlank(message = "设备编码不能为空")
        private String deviceCode;

        @NotBlank(message = "设备名称不能为空")
        private String deviceName;

        @NotBlank(message = "设备类型不能为空")
        private String deviceType;

        private String deviceModel;
        private String manufacturer;
    }

    @Data
    public static class ControlRequest {
        @NotBlank(message = "设备编码不能为空")
        private String deviceCode;

        @NotBlank(message = "命令不能为空")
        private String command;
    }
}
