## 2026-10-28T13:34:12Z
You are Challenger M3-2 (teamwork_preview_challenger) assigned to Milestone 3 Empirical Verification.

Your working directory: c:\dev\UniCORE\.agents\teamwork\challenger_m3_2\

READ FIRST:
1. c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md
2. c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md
3. c:\dev\UniCORE\GEMINI.md (NO native assert() in tests, use counters and quit(code))
4. c:\dev\UniCORE\.agents\teamwork\worker_m3_2\handoff.md

TARGETS FOR CHALLENGE:
- `res://modules/physics/nuclear_decay_module.gd`
- `res://modules/physics/quantum_wavepacket_module.gd`

SCOPE:
1. Write an empirical headless challenger script in `res://tests/test_challenger_m3_2.gd`:
   - Test NuclearDecayModule: Exponential decay law N(t) = N_0 * exp(-lambda*t) over ensemble of 1,000 nuclei matching analytical within +-5% statistical error; strict 4-momentum conservation during alpha decay (p_daughter = -p_alpha); induced fission chain reaction generating Ba-141, Kr-92, and prompt neutrons with energy release; control rod absorption.
   - Test QuantumWavePacketModule: Unconditional norm preservation in 1D Cayley / Crank-Nicolson solver (relative norm drift < 1e-4 over 500 steps); quantum tunneling through rectangular potential barrier (V_0 > E) with transmission coefficient matching analytical T approx (16*E*(V_0-E)/V_0^2) * exp(-2*kappa*d); 2D staggered leapfrog wave propagation and double-slit interference.
2. Execute the test script via:
   `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_challenger_m3_2.gd`
3. Record all quantitative outputs, write `challenge_report.md` and 5-component `handoff.md` to your working directory.
4. Issue verdict (**APPROVE** or **REQUEST_CHANGES**) and send completion message to orchestrator parent.
