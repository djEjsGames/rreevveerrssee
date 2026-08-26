local M = {
  intro = require("src.dialogue_scripts_intro"),
  moriyaOmikuji = require("src.dialogue_scripts_moriya_omikuji"),
  aliceWorkshop = require("src.dialogue_scripts_alice_workshop"),
}

M.tests = {
  { label = "세이자 난입", script = M.intro },
  { label = "모리야 오미쿠지", script = M.moriyaOmikuji },
  { label = "앨리스 공방 운송", script = M.aliceWorkshop },
}

return M
