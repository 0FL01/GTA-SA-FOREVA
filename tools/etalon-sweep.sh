#!/bin/bash
# R6z etalon sweep: every R1-R6y gate in one binary + the new csduo line.
B=/workspace/build/mad-sa-linux
O=/workspace/build/etalon
mkdir -p $O
pass=0; fail=0
chk() { # chk <label> <expected-substring> <command...>
  local label="$1"; local want="$2"; shift 2
  local out
  out="$("$@" 2>&1)"
  if echo "$out" | grep -qF "$want"; then
    echo "PASS $label"; pass=$((pass+1))
  else
    echo "FAIL $label (want '$want')"
    echo "$out" | tail -4
    fail=$((fail+1))
  fi
}
export SDL_VIDEODRIVER=dummy
chk smoke smoke-ok $B --smoke
chk video video-ok $B --smoke-video
chk headless 'data-ok ticks=600' $B --headless --ticks 600
chk audio 'audio-ok backend=null' $B --smoke-audio
export -n SDL_VIDEODRIVER
export LIBGL_ALWAYS_SOFTWARE=1
chk shot 1747182466915621468 $B --shot $O/out.tga --frames 120
chk scene 8041393264061736146 $B --shot-scene $O/scene.tga --frames 30
chk e2e 'checksums=1885179052648202699,9311803278224900038,2155565298813610694' $B --e2e --path 1600,-1700,70:1683,-2285,50 --waypoints 3 --frames-per-leg 3 --out $O/e2e
chk sfxreal 16310867633259773355 $B --smoke-audio-real --bank GENRL --samples 16
chk menu 14347365074911296144 $B --shot-menu $O/menu.tga --lang english
chk nav 'selected=1 chosen=1' $B --menu-nav down,enter --out $O/nav.tga --lang english
chk coll 11598182692490058556 $B --coll-probe
chk radio 14914820248825096026 $B --smoke-radio --station RE --seconds 5
chk ped 8661044579928738921 $B --shot-ped $O/ped.tga --model cj
chk anim 4444196192875791124 $B --shot-anim $O/anim.tga --model andre --anim IDLE_stance --time 0.5
chk animseq 5401746386500127696 $B --anim-seq $O/animseq.tga --model andre --anim WALK_civi --frames 6
chk blend 'c0matchesR6j=1' $B --anim-blend $O/blend.tga
chk car 5730483265208789677 $B --shot-car $O/car0.tga --model landstal --steer 0 --spin 0
chk hour0 12424149891741056524 $B --shot-scene $O/h0.tga --frames 30 --hour 0
chk hour7 10905788431574263010 $B --shot-scene $O/h7.tga --frames 30 --hour 7
chk hour12 8440076533160693072 $B --shot-scene $O/h12.tga --frames 30 --hour 12
chk cloudy 17456348052958327601 $B --shot-scene $O/cl.tga --frames 30 --hour 12 --weather CLOUDY_LA
chk rainy 11361061957936333104 $B --shot-scene $O/rn.tga --frames 30 --hour 12 --weather RAINY_SF
chk fogcloudy 13110586735901234051 $B --shot-scene $O/fc.tga --frames 30 --hour 12 --weather CLOUDY_LA --fog
chk fogextra 17103271862050636373 $B --shot-scene $O/fe.tga --frames 30 --hour 12 --fog
chk duo 5772255422792811549 $B --shot-duo $O/duo.tga --car landstal --ped andre
chk crowd 10525445556894735238 $B --shot-crowd $O/crowd.tga
chk cs 7067056039750001653 $B --shot-cs $O/cs.tga
chk csanim 12593717684848869509 $B --shot-cs-anim $O/csanim.tga
chk csanimseq 'midMatchesR6w=1' $B --csanim-seq $O/csanimseq.tga
chk sweet 6076501667886367754 $B --shot-cs-anim $O/sweet.tga --model cssweet --bank smoke1a --anim cssweet --time 0.5
chk sweetbind 2273931685932636729 $B --shot-cs $O/cssweet.tga --model cssweet
chk drive 'checksums=6771818124858749124,13426677351635860727,5048975404012482712' $B --drive --path 1608.20,-1721.80:1755.60,-1812.30:1683.22,-2242.96 --waypoints 3 --frames-per-leg 3 --model landstal --out $O/drive
chk walk 'checksums=6943272887341086684,14267465534692917209,7125888396247038619' $B --walk --path 1645.38,-2292.76:1660.00,-2270.00:1675.00,-2250.00 --waypoints 3 --frames-per-leg 3 --model andre --anim WALK_civi --out $O/walk
echo "=== csduo (new) ==="
$B --shot-cs-duo $O/csduo.tga 2>&1 | grep -E 'csduo-load|csOffsets|csduo-cam|texcsduo-ok|csduo-ok'
echo "=== ldd ==="
ldd $B | grep -ci wine || true
echo "SUMMARY pass=$pass fail=$fail"
