/// 寵物當下的「意圖」，由 PetBrain 決定（與動畫動作分離）
enum PetBehavior {
  idle, // 發呆（坐著）
  wander, // 隨機走動
  sleep, // 睡覺
  goToFood, // 走向食物
  eating, // 進食
  affectionate, // 被撫摸 → 撒嬌

  // 小動作（隨機觸發、選單點選、或撫摸／進食／睡醒後銜接）
  lookAround, // 左右張望（發呆時隨機）
  doze, // 打盹（發呆時隨機）
  wobble, // 搖擺（飢餓發呆時隨機）
  hop, // 跳跳（撫摸或進食後）
  stretch, // 伸懶腰（睡醒後）
  circle, // 轉圈追尾（漫遊時隨機）
}