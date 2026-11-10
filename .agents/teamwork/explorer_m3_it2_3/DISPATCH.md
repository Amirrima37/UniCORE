# Dispatch: Remediation Explorer M3-IT2-3 (1PN Relativistic Precession & Inertia Tensor)

## Objective
Analyze the root causes and formulate the exact fix strategy for:
1. `NBodyGravityModule` (`res://modules/physics/n_body_gravity_module.gd`):
   - In `_compute_1pn_pair`:
     Notice that `r_vec` is defined as `pos_j - pos_i = -\vec{r}$ (inward towards central body).
     The standard Einstein-Infeld-Hoffmann (EIH) acceleration has outward $\vec{r}$:
     $$\Delta\vec{a}_{1PN} = \frac{GM}{c^2 r^3} \left[ -\left(\frac{4GM}{r} - v^2\right)\vec{r} + 4(\vec{r}\cdot\vec{v})\vec{v} \right]$$
     With inward `r_vec`, the cross term should be `-4.0 * r_vec.dot(v_rel) * v_rel`. The code currently has `+4.0 * r_vec.dot(v_rel)`.
   - In `_evaluate_forces_barnes_hut`:
     Lines 378-386 apply the Special Relativistic acceleration tensor ($\vec{a}_{rel} = \frac{1}{\gamma}[\vec{a}_{eff} - (\vec{a}_{eff}\cdot\vec{v}/c^2)\vec{v}]$) on top of $\vec{a}_{eff} = \vec{a}_N + \vec{a}_{1PN}$.
     Because 1PN EIH acceleration is already the full laboratory coordinate acceleration from the geodesic equation (including $O(c^{-2})$ terms), dividing by $\gamma$ double-counts relativistic inertia, causing severe force damping, retrograde advance ($-47.9^\circ$), and 441% error vs analytical $+57.6^\circ$ Einstein advance.
   - Formulate the exact fix: Correct the cross-term sign, and ensure the SR acceleration tensor is NOT applied when 1PN is active (or only applied to Newtonian acceleration when 1PN is disabled).

## Inputs
- `c:\dev\UniCORE\ORIGINAL_REQUEST.md`
- `c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md`
- `c:\dev\UniCORE\.agents\teamwork\challenger_m3_1_rep\handoff.md`
- `c:\dev\UniCORE\.agents\teamwork\reviewer_m3_1_rep\handoff.md`
- Target file: `res://modules/physics/n_body_gravity_module.gd`

## Output
Write detailed mathematical derivation and exact GDScript code diffs/replacements to:
`c:\dev\UniCORE\.agents\teamwork\explorer_m3_it2_3\plan_1pn_precession_remediation.md`
and write your completion `handoff.md`.


## 2026-10-28T15:30:48Z
Received dispatch message from parent e9e803a1-ad51-4bb6-bbd9-5c64a9f0d796:
Analyze the 1PN post-Newtonian relativistic perihelion precession defects (inward r_vec cross-velocity sign error and double-counting Special Relativistic acceleration tensor) and formulate an exact mathematical derivation and code replacement plan.
Write your analysis and replacement plan to c:\dev\UniCORE\.agents\teamwork\explorer_m3_it2_3\plan_1pn_precession_remediation.md
Write your completion handoff.md and send a completion message to your parent using send_message. Do NOT edit source code files.
