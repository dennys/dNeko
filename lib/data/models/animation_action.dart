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
}