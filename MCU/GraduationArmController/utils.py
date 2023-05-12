import math

def lerp_ease_in_out(value, target, percent):
    """输出平滑结果，输入-输出曲线整体呈淡入淡出趋势，使得数值变化不会剧烈开始和停止

    Args:
        value (float): 起始值
        target (float): 目标值
        percent (float): 百分比，0-1

    Returns:
        float: 经曲线平滑后的新值
    """
    if percent >= 0 and percent <= 0.5:
        percent = math.pow(2 * percent, 3) / 2
    else:
        percent = (math.pow(2 * percent - 2, 3) + 2) / 2
    return value + (target - value) * percent

def clamp(value, min, max):
    """钳制value到min和max之间

    Args:
        value (float)
        min (float)
        max (float)

    Returns:
        float
    """
    if value < min:
        return min
    elif value > max:
        return max
    return value