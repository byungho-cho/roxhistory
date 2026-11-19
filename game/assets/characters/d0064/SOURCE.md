# D0064 run-only comparison clips

These two Animation resources are extracted from the approved comparison sources,
not replacements for the deployed models. No mesh, material or texture is included.
Both use the deployed d0057 rig and its original track paths.

| Character | Drive source ID | SHA-256 | Native run period |
| --- | --- | --- | --- |
| Han | 1mJ9fXOiRHsHNpVSdUgtLLmwz635OSW5n | 96c8589cbd73fb47cdc232a3f4c7a707f6b09008c584736d0cd3d0c4a1af176a | 0.4333333373 s |
| Sae | 1EuZfM-BFVdJ68AAfDOtsphCkxOjP55bE | 871717ac036c0d560366f4984b5f15d97bcb5d0bb8b66177c5a76bef6b737e9c | 0.3666666746 s |

Only model-test mode C loads these clips in a private AnimationLibrary.
Mode A retains Timing's 0.4-second phase mapping; B samples the original native
run at 1.5x; C uses its own native period. All share one UI clock and screen
translation derived from A, bounded to 0.6 seconds in fixed-path preview.
Gameplay adapters and Timing are unchanged.
