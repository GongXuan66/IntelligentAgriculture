from app.tools.device_tools import (
    get_all_devices,
    get_devices_by_point_id,
    get_device_by_device_code,
    control_device
)
from app.tools.rag_tools import (
    search_knowledge_base,
    rebuild_knowledge_index
)
# 导入其他tools...

__all__ = [
    "get_all_devices",
    "get_devices_by_point_id",
    "get_device_by_device_code",
    "control_device",
    "search_knowledge_base",
    "rebuild_knowledge_index",
    #TODO其他 tools
]

#TODO 现在只有读取相关的调用和控制灌溉的方法，其他修改的方式待添加
#建议使用agent子代理的形式才处理这么多的工具