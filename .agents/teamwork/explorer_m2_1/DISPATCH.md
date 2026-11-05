## 2026-10-28T12:11:10Z
You are Explorer M2-1 for Milestone 2 (Conservation Law Sentry & Spatial Partitioning).
Your working directory is: c:\dev\UniCORE\.agents\teamwork\explorer_m2_1\

MANDATORY FIRST STEP:
Read the authoritative user request at:
c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md

And read the project specification at:
c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md
and spec inventory at:
c:\dev\UniCORE\.agents\teamwork\spec_miner_survey\spec_inventory.md

Your focus:
1. Design concrete implementation strategy for `ConservationSentry` (res://core/physics/conservation_sentry.gd, extends Node).
2. Formulate continuous real-time auditing of Noether invariants:
   - Kinetic energy: 0.5 * sum(m_i * |v_i|^2)
   - Potential energy: via `potential_calculator: Callable`
   - Total energy: E = E_k + E_p
   - Relative energy drift: |E(t) - E(0)| / |E(0)|
   - Linear momentum: P = sum(m_i * v_i)
   - Angular momentum: L = sum(r_i x (m_i * v_i))
   - Instantaneous kinetic temperature: T = (2.0 / (3.0 * N * k_B)) * E_k
3. Detail signals: `invariants_updated(snapshot: Dictionary)`, `conservation_warning(violation_type: String, relative_drift: float)`.
4. Detail audit dictionary format and methods: `register_system`, `audit`, tolerance threshold `energy_tolerance = 0.005`.
5. Design Kepler 2-body orbit test under `VerletIntegrator` ensuring sentry reports drift < 0.001 and constant L vector.
6. Write findings and blueprint to c:\dev\UniCORE\.agents\teamwork\explorer_m2_1\exploration_report.md and create c:\dev\UniCORE\.agents\teamwork\explorer_m2_1\handoff.md.
7. When complete, send a message to the orchestrator parent.
