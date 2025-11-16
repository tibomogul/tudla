### ## The "Dev Team Daily" System

Designed to be scanned in 30 seconds but provides all the critical details if someone wants to look closer.

* **My Vibe:** A single emoji and a few words to set the tone.
* **Yesterday's Wins (Completed Tasks):** Where you show what you've shipped. This is where we'll track time variance.
* **Today's Focus & Status:** The plan for today, showing the health of the overall epic and remaining time.
* **Blockers / @Mentions:** Any impediments or requests for collaboration.

#### **Emoji Key:**

* **Epic Health:** :large_green_circle: `On Track`, :large_yellow_circle: `At Risk`, :red_circle: `Off Track`
* **Task Status:** :white_check_mark: `Done`, :hammer: `In Progress`, :soon: `Up Next`, :construction: `Blocked`

---

### ## How It Looks in Action

Let's imagine it's **Tuesday morning**. Your developer, Alex, is working on a big 6-week epic and just started a smaller 2-week one.

#### **Alex's Update on Monday (for context):**

> **My Vibe:** :rocket: Ready to get started on the new epic!
> 
> **Today's Focus & Status:**
> :large_green_circle: **Epic: User Profile Redesign** (5w)
> * :hammer: `Set up database schema (Est: 1d)`
> * :soon: `Build authentication endpoints (Est: 2d)`
> :large_green_circle: **Epic: Analytics Bug Fix** (2w)
> * :soon: `Replicate production bug (Est: 0.5d)`
> 
> **Blockers / @Mentions:**
> * None yet!

#### **Alex's Update on Tuesday (showing progress and risk):**

> **My Vibe:** :thinking_face: A bit of a puzzle this morning, but making progress.
> 
> **Yesterday's Wins (Completed Tasks):**
> * :white_check_mark: `Set up database schema (Est: 1d, Actual with AI: 1.5d)`
> 
> **Today's Focus & Status:**
> :large_yellow_circle: **Epic: User Profile Redesign** (5w) - *Moving to 'At Risk' as the schema work uncovered some complexities that took extra time.*
> * :hammer: `Build authentication endpoints (Est: 2d)`
> * :soon: `Write API documentation (Est: 1d)`
> :large_green_circle: **Epic: Analytics Bug Fix** (2w)
> * :hammer: `Replicate production bug (Est: 0.5d)`
> 
> **Blockers / @Mentions:**
> * :construction: The analytics bug is proving tricky to replicate. @Sam, could you help me confirm the steps to reproduce it when you have a moment?

---

### ## Why This System Works

* **Shows Movement:** The "Yesterday's Wins" section gives a clear sense of forward motion.
* **Flags Time Variance:** The `(Est: 1d, Actual: 1.5d)` format immediately and concisely shows that a task took longer than planned, which is the *exact* reason the epic status changed from :large_green_circle: to :large_yellow_circle:.
* **Hierarchical Risk is Clear:** You can see the main epic is `At Risk` while the individual task for today is still `In Progress`. This communicates the big picture without creating panic. The remaining time also puts emphasis on the timebox.
* **Quick to Read:** A manager or teammate can glance at the Vibe and the Epic Health emojis and know instantly if things are okay or if they should read more closely.

### ## The "Dev Team Daily" Emoji Cheat Sheet

Emojis and their Slack shortcodes.

#### **My Vibe (The Daily Mood)**

* :rocket: `:rocket:` - Making fast progress, launching something new.
* :sunglasses: `:sunglasses:` - On a roll, feeling productive, "in the zone."
* :thinking_face: `:thinking_face:` - Deep in thought, solving a tricky problem.
* :bulb: `:bulb:` - Had a great idea, found a solution.
* :jigsaw: `:jigsaw:` - Working on a complex piece of a larger project.
* :handshake: `:handshake:` - In meetings, collaborating, pairing with someone.
* :headphones: `:headphones:` - Deep focus, head down in code.
* :man-running::skin-tone-4: `:man-running:` - Falling behind, action necessary
* :hot_face: `:hot_face:` - Pressure is on
* :firefighter::skin-tone-4:  `:firefighter:` -"Fire-fighting"

---

#### **Epic Health (The Big Picture)**

This tracks the overall status of the multi-week effort.

**Traffic Light Theme:**

* **On Track:** :large_green_circle: `:green_circle:`
* **At Risk:** :large_yellow_circle: `:yellow_circle:`
* **Off Track:** :red_circle: `:red_circle:`

#### Non-epic Work
* Research / Investigation: :microscope: `:microscope:`
    Use Case: Exploring new technologies, deep-diving into a problem, investigating a new tool. (e.g., "Leveraging AI in projects").
* Proof of Concept (PoC) / Prototyping: :hammer_and_wrench: `:hammer_and_wrench:`
    Use Case: Building a small-scale version to test a hypothesis or demonstrate a new architecture.
* Process / Tooling Improvement: :seedling: `:seedling:`
    Use Case: Improving CI/CD pipelines, refining the team's agile process, introducing a new linter, adding AI best practices
* Learning / Professional Development: :brain: `:brain:`
    Use Case: Completing a certification, learning a new language or framework.
* Customer Support: :adhesive_bandage: `:adhesive_bandage:`
    Use case: This is a fantastic metaphor for support work. It perfectly captures the idea of applying a fix, patching a problem for a customer, and providing care to make things better. It's simple, universally understood, and distinct from our other emojis.
* Critical Support / Firefighting: :fire_extinguisher: `:fire_extinguisher:`
    Use Case: This is great for more urgent, high-priority customer issues that feel like a "rescue mission."
* Ticket-Based Work: :admission_tickets: `:admission_tickets:`
    Use Case: A very literal and clear way to show you're working through the support queue or specific customer tickets.
* Direct Communication: :speaking_head_in_silhouette: `:speaking_head_in_silhouette:`
    Use Case: This works well if the support task is more about talking directly with customers, gathering feedback, or walking them through a solution.
* Housekeeping: :broom: `:broom:`
    Use Case: For any internal work, for the team or special tasks that are not professional development.

---


#### **Task Status (The Daily Grind)**

This shows the status of individual tasks for the day.

* **Done:** :white_check_mark: `:white_check_mark:`
* **In Progress:** :hammer: `:hammer:`
* **Up Next:** :soon: `:soon:`
* **Blocked:** :construction: `:construction:`
* **Blocked by a Dependency :link: `:link:` 
* **Need Information :question: `:question:` 

---