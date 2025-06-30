# Project Learnings
A reflection and summary of the key learnings from the project.

## Key Learnings

- Flowcharting
    - Maintaining a high and low-level algorithm flowchart for the MC logic would have been beneficial, even if most of the logic implemented was discovered and learnined through the process of building the project.

- Vibe Coding:
    - Very powerfull for docstring and inline code documentation and for exception handling. It is great to generat a first template for a script, but has the disadvantage of suppressing the initial class and modul structure design.

    - Best application is to create first the layout of classes and methods by its own, resp. having a proper vision of the code, and then let the AI generate a first draft for the methods.

    - Debugging error message can be done very effectively, but one should stop after three unsuccessfull attempts.

    - Never refactor larger code with GenAI. One will loose the overview and the code can become overengineered.

- Multi Environment Development:
    - Developing, resp. running code in multienvironments, like locally on WSL with normal Python (for testing) and later on ESP32 with MicroPython, can be tricky. A try-except library import and mock libraries can be a simple solution to avoid import errors.

- Variables
    - Centralized variable and config files are key. Create a single source of truth for all variables and configurations to avoid inconsistencies and make it easier to manage changes.
