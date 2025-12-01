using UnityEngine;

public class CameraTracker : MonoBehaviour
{
    [Header("Target")]
    public Transform target; // 把陨石拖到这里

    [Header("Settings")]
    public float rotationSpeed = 10.0f; // 镜头转动平滑度

    void LateUpdate() // 相机跟随通常放在 LateUpdate 以防抖动
    {
        // 1. 如果陨石销毁了，就停止跟踪，保持最后姿势
        if (target == null) return;

        // 2. 计算从摄像机指向陨石的向量
        Vector3 direction = target.position - transform.position;

        // 3. 计算目标旋转角度 (LookRotation)
        Quaternion targetRotation = Quaternion.LookRotation(direction);

        // 4. 将旋转转换为欧拉角 (Euler Angles) 以便我们可以限制 X 轴
        Vector3 currentEuler = targetRotation.eulerAngles;

        // --- 核心逻辑：限制角度 ---
        // Unity 的角度是 0-360。
        // 抬头是 300~360 (即 -60 ~ 0)，平视是 0，低头是 0~90。
        // 我们要把 300~360 转换成负数，方便比较。
        
        float xAngle = currentEuler.x;
        // 如果角度大于 180，说明它是抬头角度（例如 350度 = -10度），我们要把它转成 -10
        if (xAngle > 180) xAngle -= 360;

        // 现在的逻辑很简单：
        // 如果 xAngle > 0 (说明想要低头看地下的陨石)，就强制设为 0 (平视)
        if (xAngle > 0)
        {
            xAngle = 0;
        }

        // 5. 应用旋转
        // 我们只改变 X轴（上下看），保留原来的 Y轴（左右看）和 Z轴（0）
        // 如果你也希望摄像头左右跟着陨石转，把 yAngle 也设为 targetRotation.eulerAngles.y
        float yAngle = targetRotation.eulerAngles.y; 

        Quaternion finalRotation = Quaternion.Euler(xAngle, yAngle, 0);

        // 使用 Slerp 进行平滑插值，这样看起来更像电影运镜
        transform.rotation = Quaternion.Slerp(transform.rotation, finalRotation, Time.deltaTime * rotationSpeed);
    }
}