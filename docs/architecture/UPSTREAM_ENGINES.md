# Upstream engine migration checkpoint

2026-11-12, existing master HEAD 13e40a5a565a273485aa80ea14ed110df36136a2.
Existing dirty files and Stage 7 numerical evidence were preserved. No custom kernel was removed.

## Verified sources

Gmsh: [official project](https://gmsh.info/), canonical repository
https://gitlab.onelab.info/gmsh/gmsh.git, maintained by Christophe Geuzaine and
Jean-Francois Remacle. Official stable release inspected: 4.15.2.
Windows SDK acquired (42,334,565 bytes), SHA-256 in engines.lock.json.
GPL-2.0-or-later with upstream linking exception; retain notices, license and
provide corresponding source under applicable redistribution terms. No binary
redistribution is added to this repository. Windows 10+, Linux and macOS SDKs;
C/C++/Python/Julia/Fortran APIs and CLI; source uses CMake and C++ with optional
OCCT, FLTK, mesh libraries. SDK includes OCCT and tutorials. Extracted DLL is
89,212,416 bytes; full source build requirements have not been measured.
Exact source commit is unresolved; release archive pin is used, not an invented SHA.
Matching source archive acquired and tar listing checked. Its measured SHA-256
is in the lock manifest. Source compilation has not been attempted; the local
native test was compiled against the prebuilt SDK.
Native C API smoke: block B-Rep volume 6 and 932 TET4 cells, STEP/MSH export.
This does not establish direct OCCT library integration or solver integration.

CalculiX: [official project](https://calculix.de/), solver author distribution
https://www.dhondt.de/; release observed 2.23. Windows packaging repository
https://github.com/calculix/CalculiX-Windows at
60c9a10b350ec813f4d493098f47f7a8b96cd276 (resolved with git ls-remote).
The packaging repository downloads solver sources and dependencies; it is not
the canonical solver source tree. No solver acquired, built or executed yet.
License/dependency audit and exact solver source pin remain required.

## Remaining acquisition queue — unverified

OCCT; Code_Aster; both OpenFOAM distributions; SU2; OpenRadioss and successors;
Chrono; Elmer; GetDP; Palace; openEMS; FEMM; MEEP; Cantera; preCICE and its
OpenFOAM/CalculiX adapters; VTK; OpenModelica; OpenMDAO; MFEM; deal.II;
FEniCSx; Capytaine; OpenFAST; MercuryDPM; Bempp; RayOptics; Optiland; pyMOR.

These are an acquisition queue, not available backends. Their canonical sources,
release/commit, licenses, platform/compiler requirements, sizes, examples and
maintenance status have **not** been verified in this checkpoint. Do not use
user-supplied URLs as verified dependency pins. In particular OpenRadioss
maintenance and Code_Aster hosting still require investigation.

## Environment blockers

Sandbox networking failed; approved external execution allowed the Gmsh download
and revision lookup. WSL distribution listing returned Wsl/E_ACCESSDENIED.
CIM RAM inspection was denied and disk free space was unavailable via PSDrive;
no heavyweight build was attempted. Unprefixed g++.exe failed as an invalid
Windows executable; the repository's x86_64-w64-mingw32-g++.exe worked.

CAD expansion: PARTIAL infrastructure only; see docs/architecture/CAD_MESHING_CHECKPOINT.md. No new native or GUI acceptance claimed.
