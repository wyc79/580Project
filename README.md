# Asterois Impact

University of Southern California CSCI 580 Fall 2025 Final Project

## Folder Structure

```shell
.
└── 580Project 									# Unity6 project folder root
    └── Assets
        ├── Models
        │   ├── Forest_1						# model downloaded from internet
        │   ├── Forest_2						# another model (actually used)
        │   ├── Forest_2_custom			        # modified model 2
        │   └── Landscape						# another model (not used)
        ├── Scenes
        │   ├── MainScene						# old scene, no longer used
        │   └── Scene2						    # scene used 
        ├── Scripts
        │   ├── Deform							# C# scripts driving defrom & fadeout shader
        │   └── RadialImpact				    # C# scripts driving post-processing shaders
        ├── Settings
        ├── Shaders
        │   ├── DeformShader				    # Deform & fade out shader & material
        │   │   └── DeformMaterials	            # materials created from deform shader
        │   ├── ForceField                      # Shockwave Shader
        │   ├── Light.shader                    # Asteroid and lighting effect
        │   └── RadialImpact                    # Radial Impact Post-Processing
        ├── Texture								# Particle system
        └── TutorialInfo						# (not used)
```

## Instruction to run

Load the project into the Unity editor, and run the project after it has been successfully loaded. 

Hit play in the editor. The scene will play automatically. Press space to replay the terrain deformation effect (the asteroid will not fall).

