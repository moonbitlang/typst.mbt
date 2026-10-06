// basic-resume 0.2.9: a two-page US-letter resume with every header field (pronouns, phone,
// location, email, GitHub, LinkedIn, site, ORCID with the scienceicons icon), a coloured
// accent, and all entry helpers: edu, work, project (with and without role, url, dates),
// certificates, extracurriculars, dates-helper, nested lists.
// Engine paths: show rules on heading levels and links (underline + fill), `h(1fr)` rows,
// inline SVG icon from a package (image decoded from bytes), ligatures off, justified lists.
#import "@preview/basic-resume:0.2.9": *

#show: resume.with(
  author: "Thandiwe Mbeki",
  pronouns: "she/her",
  location: "Cape Town, South Africa",
  email: "thandiwe.mbeki@riverlab.example",
  github: "github.com/tmbeki-hydro",
  linkedin: "linkedin.com/in/thandiwe-mbeki",
  phone: "+27 21 555 0142",
  personal-site: "mbeki-hydro.example",
  orcid: "0000-0002-1825-0097",
  accent-color: "#0b5d6b",
  font: "New Computer Modern",
  paper: "us-letter",
  author-position: left,
  personal-info-position: left,
)

== Summary

Hydrologist with nine years of experience in catchment modelling and flood forecasting for
semi-arid river basins. I build forecasting systems that operators trust at three in the
morning: small, tested, and honest about their uncertainty.

== Education

#edu(
  institution: "University of the Western Cape",
  location: "Bellville, South Africa",
  dates: dates-helper(start-date: "Feb 2014", end-date: "Dec 2017"),
  degree: "PhD, Environmental and Water Science",
)
- Thesis: _Ensemble streamflow forecasts for ungauged tributaries of the Berg River_
- Supervised four honours projects on rainfall-runoff calibration

#edu(
  institution: "Stellenbosch University",
  location: "Stellenbosch, South Africa",
  dates: dates-helper(start-date: "Feb 2010", end-date: "Dec 2013"),
  degree: "BEng, Civil Engineering (cum laude)",
  gpa: "82 %",
)
- Final-year design: a stormwater detention pond for a 14 ha township extension
- Electives: Open-Channel Hydraulics, Numerical Methods, Remote Sensing, Statistics II

== Work Experience

#work(
  title: "Senior Forecasting Hydrologist",
  location: "Cape Town",
  company: "Western Rivers Flood Centre",
  dates: dates-helper(start-date: "Mar 2021", end-date: "Present"),
)
- Lead a team of five that issues daily flow forecasts for 38 gauging stations
- Replaced a spreadsheet workflow by a reproducible pipeline; the morning bulletin now goes
  out 70 minutes earlier
  - Cut the median absolute error of the 48-hour forecast from 23 % to 14 %
  - Introduced probabilistic warnings with three calibrated thresholds
- Wrote the centre's incident handbook after the floods of June 2023

#work(
  title: "Hydrological Modeller",
  location: "Pretoria",
  company: "Institute for Rural Networks, Water Group",
  dates: dates-helper(start-date: "Jan 2018", end-date: "Feb 2021"),
)
- Calibrated distributed models for six catchments between 80 and 4,200 km#super[2]
- Built a gauge-quality dashboard that flagged 11 failing stations in its first month
- Trained 30 municipal engineers in rating-curve maintenance over three field seasons

#work(
  title: "Graduate Engineer",
  location: "Paarl",
  company: "Drakenstein Municipality, Stormwater Section",
  dates: dates-helper(start-date: "Jan 2013", end-date: "Jan 2014"),
)
- Surveyed 62 culverts and prioritised nine for replacement
- Automated the monthly rainfall report with a script that is, reportedly, still in use

#work(
  title: "Field Assistant",
  location: "Citrusdal",
  company: "Olifants River Monitoring Programme",
  dates: dates-helper(start-date: "Dec 2011", end-date: "Feb 2012"),
)
- Measured discharge at twelve cross-sections with a current meter, twice weekly
- Maintained four tipping-bucket rain gauges and their loggers

== Projects

#project(
  name: "bergflow",
  role: "Author and maintainer",
  dates: dates-helper(start-date: "Aug 2019", end-date: "Present"),
  url: "bergflow.example",
)
- A small library for conceptual rainfall-runoff models with exact unit tests of the mass
  balance; used in two university courses
- 3,400 lines of code, 96 % branch coverage, no dependencies beyond the standard library

#project(
  name: "Rating-curve atlas",
  dates: dates-helper(start-date: "Jun 2020", end-date: "Nov 2020"),
)
- Digitised 140 historical rating curves from paper archives and published them as open data

#project(
  name: "Gauge-photo reader",
  role: "Contributor",
  url: "example.org/gauge-reader",
)
- Reads staff-gauge levels from phone photographs sent in by farmers; accurate to 2 cm in
  daylight

#project(
  name: "Flood-memory walks",
)
- Annual guided walk along the flood marks of 1954, 1977 and 2008 for local schools

== Certificates

#certificates(
  name: "Professional Engineer (Pr.Eng.)",
  issuer: "Engineering Council of South Africa",
  date: "Sep 2019",
)

#certificates(
  name: "Swift-water Rescue Technician",
  issuer: "Rescue Training Institute",
  url: "rti.example/swr",
  date: "Apr 2022",
)

== Extracurricular Activities

#extracurriculars(
  activity: "Volunteer river warden, Liesbeek",
  dates: dates-helper(start-date: "2016", end-date: "Present"),
)
- Monthly water-quality sampling at three sites; data published at
  #link("https://example.org/liesbeek")[example.org/liesbeek]
- Organised the removal of 4 t of invasive water hyacinth with 60 volunteers

#extracurriculars(
  activity: "Mentor, Girls in Engineering Week",
  dates: dates-helper(start-date: "2019", end-date: "2023"),
)
- Ran a hands-on flume workshop for 25 pupils each winter

== Skills
- *Modelling*: conceptual and distributed rainfall-runoff models, ensemble forecasting,
  data assimilation, flood-frequency analysis, uncertainty quantification
- *Programming*: Python, R, Fortran, SQL, Bash; version control, continuous integration
- *Field*: current meter and ADCP gauging, levelling, logger maintenance
- *Languages*: isiXhosa (native), English (fluent), Afrikaans (fluent), Portuguese (basic)

== Selected Publications
+ T. Mbeki, R. Castellanos. "Three seasons of radio telemetry in the Olifants basin."
  _Water Networks Review_ 12 (2022), 41#sym.dash.en;58.
+ T. Mbeki. "What a forecaster owes the night shift." _Proceedings of the Southern African
  Hydrology Symposium_, 2023.
