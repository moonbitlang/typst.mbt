// modern-cv 0.10.0: an English resume with every author field (birth, phone, email, homepage,
// GitHub, GitLab, Bitbucket, LinkedIn, Twitter, Bluesky, Mastodon, Scholar, ORCID, website,
// custom items with and without icon, address with icon), no profile picture, and all
// section helpers: resume-entry (with title-link), resume-item, resume-gpa,
// resume-certification, resume-skill-item, resume-skill-grid, github-link, plus a
// publication list from a .bib (`full: true`). Two pages with the footer.
// Engine paths: fontawesome fallback glyphs (missing icon fonts), linguify lookups from
// TOML, `set document` inside context, sticky blocks, `box(width: 1fr)` rules, text weights
// "thin"/"light" resolved against the embedded fonts, page footer with counter.
#import "@preview/modern-cv:0.10.0": *

#show: resume.with(
  author: (
    firstname: "Rui",
    lastname: "Castellanos",
    email: "rui@castellanos.example",
    homepage: "https://castellanos.example",
    phone: "(+351) 22 555 0117",
    github: "rcastellanos",
    gitlab: "rcastellanos",
    bitbucket: "rui-castellanos",
    twitter: "ruicodes",
    bluesky: "rui.castellanos.example",
    mastodon: "ruicodes",
    scholar: "kX9aB3cAAAAJ",
    orcid: "0000-0002-7183-4567",
    birth: "17 June 1991",
    linkedin: "rui-castellanos",
    address: "Rua das Flores 112, 4050-262 Porto, Portugal",
    website: "https://blog.castellanos.example",
    positions: (
      "Distributed Systems Engineer",
      "Storage Specialist",
      "Occasional Lecturer",
    ),
    custom: (
      (text: "Conference talks", icon: "person-chalkboard", link: "https://castellanos.example/talks"),
      (text: "PGP 4A1F 9C02", icon: "key", link: "https://castellanos.example/pgp.asc"),
      (text: "Availability", link: "https://castellanos.example/calendar"),
    ),
  ),
  keywords: ("distributed systems", "storage", "consensus"),
  description: "Résumé of Rui Castellanos, distributed systems engineer",
  profile-picture: none,
  date: "6 October 2026",
  language: "en",
  colored-headers: true,
  show-footer: true,
  show-address-icon: true,
  paper-size: "a4",
)

= Experience

#resume-entry(
  title: "Staff Engineer, Storage",
  location: "Porto, Portugal",
  date: "2021 - Present",
  description: "Douro Data Systems",
  title-link: "https://dourodata.example",
)

#resume-item[
  - Own the replication layer of a log-structured store serving 40 billion requests a day
  - Designed lease-based reads that removed a round trip from 92 % of queries
  - Introduced deterministic simulation testing; it has found 61 bugs before release, among
    them three that could lose acknowledged writes
  - Mentor four engineers; two were promoted to senior in the last cycle
]

#resume-entry(
  title: "Senior Software Engineer",
  location: "Lisbon, Portugal",
  date: "2017 - 2021",
  description: "Tagus Cloud",
)

#resume-item[
  - Rewrote the metadata service from a single leader to a replicated state machine
  - Reduced p99 write latency from 180 ms to 23 ms by batching log appends
  - On-call lead for the storage rotation during two regional outages
]

#resume-entry(
  title: "Software Engineer",
  location: "Braga, Portugal",
  date: "2014 - 2016",
  description: "Minho Telemetry",
)

#resume-item[
  - Built the ingestion path for 300,000 industrial sensors
  - Wrote the on-disk format still used by the product today
]

= Projects

#resume-entry(
  title: "quorumkit",
  location: [#github-link("rcastellanos/quorumkit")],
  date: "2019 - Present",
  description: "Author and maintainer",
)

#resume-item[
  - A consensus library with a model-checked specification and a simulator
  - 2,100 stars, 46 contributors, used in production by five companies
]

#resume-entry(
  title: "skewlab",
  location: [#github-link("rcastellanos/skewlab")],
  date: "2022",
  description: "Author",
)

#resume-item[
  - Injects clock skew and drift into containers for testing time-dependent protocols
]

= Skills

#resume-skill-item(
  "Languages",
  (strong("Rust"), strong("Go"), "C++", "Python", "TLA+"),
)
#resume-skill-item("Spoken Languages", (strong("Portuguese"), strong("English"), "Spanish", "French"))
#resume-skill-item(
  "Systems",
  ("consensus protocols", "log-structured storage", "deterministic simulation", "performance analysis"),
)

#resume-skill-grid(
  categories-with-values: (
    "Tooling": ("perf", "eBPF", "Jepsen-style testing", "Bazel"),
    "Operations": ("capacity planning", "incident command", "postmortems"),
    "Teaching": ("guest lectures", "reading groups", "interview training"),
  ),
)

= Education

#resume-entry(
  title: "Universidade do Porto",
  location: "Porto, Portugal",
  date: "2014 - 2016",
  description: "MSc in Informatics and Computing Engineering",
)

#resume-item[
  - Thesis on recovery protocols for log-structured stores, graded 19 out of 20
  - Teaching assistant for Operating Systems, two semesters
]

#resume-gpa("18.4", "20")

#resume-entry(
  title: "Universidade do Minho",
  location: "Braga, Portugal",
  date: "2009 - 2014",
  description: "BSc in Computer Science",
)

#resume-item[
  - Exchange year at the Technical University of Brno
]

= Certifications

#resume-certification("Site Reliability Foundations, Level 3", "Mar 2023")
#resume-certification("Formal Methods Summer School, Certificate of Completion", "Jul 2019")

= Publications

#{
  set text(size: 10pt, weight: "light")
  bibliography("publications.bib", full: true, title: none, style: "ieee")
}

= Talks and Community

#resume-item[
  - "What your leases assume about time", keynote at a regional systems meetup, 2023
  - Organiser of the Porto Papers reading group since 2018: 74 sessions so far
  - Reviewer for two workshops on testing of distributed systems
]
