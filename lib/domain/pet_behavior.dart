/// 寵物當下的「意圖」，由 PetBrain 決定（與動畫動作分離）
enum PetBehavior {
  idle, // 發呆（坐著）
  wander, // 隨機走動
  sleep, // 睡覺
  goToFood, // 走向食物
  eating, // 進食
  affectionate, // 被撫摸 → 撒嬌
}