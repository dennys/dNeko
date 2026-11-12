enum AnimationAction {
  // 8 方向移動
  walkUp,
  walkDown,
  walkLeft,
  walkRight,
  walkUpLeft,
  walkUpRight,
  walkDownLeft,
  walkDownRight,
  walkSide, // 正側面走（鼻尖朝左，走向右時鏡像）

  // 特殊動作
  sit, // 坐下
  sleep, // 睡覺
  eat, // 進食
  affectionate, // 撒嬌

  // 以下沒有專用素材：由 AnimationDefinition 的 alias 借用現有幀，見 _missingFrameAlias
  lookAround, // 左右張望（坐著 + 鏡像）
  doze, // 打盹（坐著 + 慢速點頭）
  wobble, // 搖擺（坐著 + 左右晃）
  hop, // 跳跳（坐著 + 彈跳）
  stretch, // 伸懶腰醒來（撒嬌幀播一次）
}