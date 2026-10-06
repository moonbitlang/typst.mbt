// modern-cv 0.10.0: deliberately fails inside the package: a `custom` contact item without a
// `link` reaches `link("" + none)` ("URL must not be empty").
// Engine paths: error with a trace through three package closures, warnings emitted before
// the error (unknown fonts), `str + none` joining.
#import "@preview/modern-cv:0.10.0": *

#show: resume.with(
  author: (
    firstname: "Samira",
    lastname: "Ibrahim",
    email: "samira@ibrahim.example",
    positions: ("Scheduler", "Planner"),
    custom: (
      (text: "Office hours on Thursdays", icon: "clock"),
    ),
  ),
  profile-picture: none,
  date: "6 October 2026",
)

= Experience

#resume-entry(title: "Planner", location: "Cairo", date: "2020 - Present", description: "Nile Logistics")
