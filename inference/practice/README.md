# Practice: from knowing to doing

The notes explain. This folder trains the three things you will actually do with inference customers: **estimate** a number without a tool, **diagnose** a problem from metrics, and **talk** it through with someone who is not an engineer.

| Skill | Practise with | You are ready when |
| --- | --- | --- |
| Estimate | [drills.md](drills.md): 16 questions on paper | You get the order of magnitude right in two minutes, and know which equation (note 18) you used |
| Diagnose | [cases.md](cases.md): 12 tickets, solved blind | You name metric, layer, phase and ceiling (note 25) before opening the solution, in at least 9 of 12 |
| Talk | Role-play in note 26, and the "to the customer" part of every case | Your reply has assumptions, a range and how you will confirm it, without jargon |
| Put it together | Note 27, then a new scenario of your own | You can size a deployment for a model and GPU that no note covers, and defend it |

## How to use the cases

1. **Blind:** read the ticket and the snapshot only. Do not open the solution.
2. **Write**, do not just think: the five steps of note 25, then the three-part reply of note 26.
3. **Compare** with the solution. Where you differ, find the equation or note you missed and reread it.
4. **Repeat a week later.** The second time, time yourself: 10 minutes per case.

Better still, in pairs: one plays the customer and reveals the snapshot only when asked the right question. That trains the hardest part, knowing what to ask.

## Write your own questions

The best test of understanding is generating questions, not answering them. After each note of phase 3, write:

- one question a customer could ask that the note answers;
- one question the note does **not** answer, and which equation you would start from;
- one way a customer could misread the note's main number.

Bring them to the next session or add them as new cases here.

## A study plan

| Week | Read | Practise |
| --- | --- | --- |
| 1 | Notes 01–08 | Run the `curl` examples against Ollama |
| 2 | Notes 09–17 | Note 17 "Try it" by hand |
| 3 | Notes 18–21 | Drills 1–10; `fit.py` on three models you care about |
| 4 | Notes 22–24 | Apply the `PrometheusRule` on the level 8 stack; drills 11–16 |
| 5 | Notes 25–27 | Cases 1–6 blind, role-play from note 26 |
| 6 | — | Cases 7–12 blind; size a deployment of your own and present it as in note 27 |
| 7 | [Level 10](../../level-10/README.md) | Build the platform on kind, then `./level-10/break.sh` until you solve each fault in under 15 minutes |
