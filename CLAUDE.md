\# Project Architecture and Design Guidelines



This project adopts a dual-track specification system. When generating, reviewing, or refactoring Flutter/Dart code, the following separation of responsibilities must be strictly observed:



\## 1. Framework \& Architecture -> Strictly follow `impeccable`

1\. \*\*Scope of Constraints\*\*: File and directory organization, component responsibility division, state management flow, data persistence, and API service invocation logic.

2\. \*\*Execution Standard\*\*: Mandatorily use the best practices defined by `impeccable` to ensure the code maintains high maintainability, modularity, and a clear unidirectional data flow.



\## 2. Visual Taste \& UI Execution -> Strictly follow `taste-skill`

1\. \*\*Scope of Constraints\*\*: Color palette, component spacing (padding/margin), typography, shadows, border radius proportions, and all frontend styling definitions.

2\. \*\*Style Anchor\*\*: Strictly enforce the `minimalist-ui` standard. The interface must feature high information density and minimal visual noise, stripping away all meaningless decorative elements to suit a data-driven bookkeeping tool.

3\. \*\*Conflict Resolution\*\*: When recommendations from `impeccable` involve specific UI parameter settings, \*\*they must be ignored. Absolutely default to the visual principles of `taste-skill`.\*\*

