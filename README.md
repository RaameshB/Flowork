<div align="center">
	<img src="data/icons/hicolor/scalable/apps/io.github.raameshb.flowork.svg" width="160" height="160"></img>

# Flowork

**Get what motivates you done, without losing concentration or driving yourself insane**

**FLATPAK LINK CURRENTLY DOES NOT POINT TO FLOWORK INSTALL; IT POINTS TO THE FLOWTIME INSTALL**
<a href="https://flathub.org/apps/details/io.github.diegoivanme.flowtime">
    <img width="200" src="https://flathub.org/assets/badges/flathub-badge-en.png" alt="Download on Flathub">
</a>

</div>

## Gallery:

<div align="center">
	<img src="https://raw.githubusercontent.com/Diego-Ivan/Flowtime/main/data/screenshots/01.png" width="283" height="286" style="padding-top=24;"></img>
	<img src="https://raw.githubusercontent.com/Diego-Ivan/Flowtime/main/data/screenshots/02.png" width="283" height="286"></img>	
	<img src="https://raw.githubusercontent.com/Diego-Ivan/Flowtime/main/data/screenshots/03.png" width="283" height="286"></img>
	<img src="https://raw.githubusercontent.com/Diego-Ivan/Flowtime/main/data/screenshots/04.png" width="283" height="286"></img>
</div>

## Features:

* Assistant for the Flowtime working technique
* Assisted time calculations for breaks
* Customizable tones for the end of the break
* Notification that alerts you when your break is done
* Work and break time statistics
* Export your statistics to CSV

## Why?

The Pomodoro technique is efficient for tasks you find boring, but having to take a break when you are 100% concentrated in something you like might be annoying. That's why the Flowtime technique exists: take appropriate breaks without losing your flow.

However, the Flowtime technique has some flaws, at least for my workflow: sometimes when you're working, the flow state is inconsistent. It happens sometimes, sometimes it doesn't and actually you're so demotivated on some days that you need to take breaks that are longer than what you've accumulated with your work time. Sometimes, you really can't as easily, and you need shorter sessions with more breaks. Sometimes you decide to not take a full break, and end up wasting the time you've accumulated, as it is reset. Flow state isn't guaranteed. Instead of having two techniques for for when you're struggling to work vs when you're in flow state, Flowork attempts _unify_ the two into a single fluid system.

## How does it work?

Flowork relies on two "time banks": Break credit and work debt. You first decide how much time on average you want to spend working, and how much time on break. The default is that your breaks are on average 33% as long as your work time. This is adjustable. 

### Core model
- When working without work debt, you build up break credit according to your break percentage.
  - i.e. If you've worked an hour without work debt, you'd have built about 20 minutes of break credit
- As you take a break, you burn through break credit, but the key deviation from Flowtime is that your break isn't forced to stop after exhausting break credit. Instead, you start building up work debt.
  - Work debt is calculated by $`\frac{1}{(\text{break percentage})/100}\times(\text{time on break without break credit})`$. For example, with a 33% break with an hour of break overtime would result in $`\frac{1}{\mathbf{33}/100}\times(\textbf{1 hour})\approx\mathbf{3}\times\textbf{1 hour}=\textbf{3 hours}`$ of work debt.
- When working with accumulated work debt, you pay it off as you work, and once it's paid off, you start accumulating break credit again.
  - You can still take breaks when you have work debt, you just end up adding more to your work debt.

### Additional tidbits
#### Credit and debt accumulation
- As a student, I've found myself having more time and/or energy on some days, and less on others.
  - To address this, Flowork can be configured to have the banks accumulate over a week.
    - For weekly resets, you can have the schedule reset on Sundays or on Mondays
  - Additionally, as one of main objectives of the Flowork technique is to prevent burnout, break credit carries over across resets.
  - You're able to configure the reset hour, i.e. you can reset at 3 AM on your selected day if you want instead of at 12 AM. This is for those night owls out there.
- The accumulation can be configured to be daily, weekly, or to have no accumulation at all. Work the same as weekly resets, only that they're executed every day.
#### Measuring if you're overworking yourself (or vice versa)
If you're ending your reset period with a ton of work debt, this means one of two cases:
- Intuitively, it's that you're not working hard enough. You know it's this case if you're measurably falling behind on work you _need_ to get done. Note the usage of _need_ instead of _want_.
- Or instead, you're not allowing yourself enough breaks and are actively in the process of burning yourself out. This is shown by you being well ahead of work you _need_ to get done, but you clearly have completely unrealistic expectations of what you _want_ to get done. Increase your break percentage in order to preserve your sanity.

Conversely, if you're ending your reset period with a ton of break credit, it means one of two other cases:
- If you're well ahead of the work you _need_ to do and are also getting a ton of work that you _want_ to do out of the way, you may want to consider relaxing and spending your break credit in order to not burn yourself out. Your break credit accumulates across resets for a reason: despite the name, it is a _debt_ to _yourself_ that you need to repay in order to preserve your sanity.
- If you're falling behind on the work you _need_ to do, then lower your break percentage; you shouldn't be accumulating break credit while actively falling behind, if anything work debt should be showing up.
## Installing and Running

### Flathub

Flowork isn't on Flathub just yet. Currently a Flatpak file is provided. Will try to get this on Flathub after I come up with a proper app icon/logo.

### Building from source

#### Flatpak and GNOME Builder

GNOME Builder provides a high quality Flatpak integration. All dependencies, runtimes and SDK extensions necessary will be installed by the application if they're not available. Just click the "Run" button and the app will be built :smile:.

#### Requirements

| Dependency | Version |
| ---------- | ------- |
| Meson | 0.59.0 |
| gtk-4  | 4.11 |
| libportal | 0.7.1 |
| libadwaita-1 |  1.4 |
| libxml-2.0 |  1.0 |

To compile and install, run:

```sh
meson builddir --prefix=/usr
cd builddir
sudo ninja install
flowork
```
