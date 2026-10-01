use time::format_description::{self, BorrowedFormatItem, Component, OwnedFormatItem};
use time::{Date, Duration, Month, PrimitiveDateTime, Time};

fn mbt_str(s: &str) -> String {
    let mut out = String::from("\"");
    for c in s.chars() {
        match c {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            '\n' => out.push_str("\\n"),
            '\t' => out.push_str("\\t"),
            '\r' => out.push_str("\\r"),
            c if (c as u32) < 0x20 || (c as u32) > 0x7e => {
                out.push_str(&format!("\\u{{{:x}}}", c as u32))
            }
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

fn comp(c: &Component) -> String {
    format!("{c:?}")
}

fn owned(item: &OwnedFormatItem) -> String {
    match item {
        OwnedFormatItem::StringLiteral(s) => format!("L({s})"),
        OwnedFormatItem::Component(c) => format!("C({})", comp(c)),
        OwnedFormatItem::Compound(items) => {
            format!("[{}]", items.iter().map(owned).collect::<Vec<_>>().join(","))
        }
        OwnedFormatItem::Optional(item) => format!("O({})", owned(item)),
        OwnedFormatItem::First(items) => {
            format!("F[{}]", items.iter().map(owned).collect::<Vec<_>>().join(","))
        }
        _ => "?".into(),
    }
}

fn borrowed(item: &BorrowedFormatItem) -> String {
    match item {
        BorrowedFormatItem::StringLiteral(s) => format!("L({s})"),
        BorrowedFormatItem::Component(c) => format!("C({})", comp(c)),
        _ => "?".into(),
    }
}

fn main() {
    let mut patterns: Vec<String> = vec![
        "[year]-[month]-[day]",
        "[hour]:[minute]:[second]",
        "[year]-[month]-[day] [hour]:[minute]:[second]",
        "[year] [month repr:long] [day] [week_number] [weekday]",
        "[year repr:last_two]",
        "[hour repr:12 padding:none]",
        "[year",
        "[nothing]",
        "[year wrong:last_two]",
        "  []",
        "[]",
        "[ ]",
        "[ year]",
        "[year ]",
        "[year  ]",
        "[hour]",
        "[day padding:space]",
        "[day padding:none]",
        "[day padding:zero]",
        "[day padding:bad]",
        "[day padding:]",
        "[day :zero]",
        "[day padding]",
        "[day padding:zero padding:space]",
        "[DAY PADDING:SPACE]",
        "[Month Repr:Short]",
        "[month repr:short case_sensitive:false]",
        "[month repr:numerical padding:space]",
        "[month repr:long padding:space]",
        "[month repr:numerical case_sensitive:false]",
        "[ordinal]",
        "[ordinal padding:space]",
        "[ordinal padding:none]",
        "[weekday repr:short]",
        "[weekday repr:long]",
        "[weekday repr:sunday]",
        "[weekday repr:monday]",
        "[weekday repr:sunday one_indexed:false]",
        "[weekday repr:monday one_indexed:false]",
        "[weekday repr:short one_indexed:false]",
        "[week_number repr:iso]",
        "[week_number repr:sunday]",
        "[week_number repr:monday]",
        "[week_number repr:monday padding:none]",
        "[week_number repr:sunday padding:space]",
        "[year repr:full]",
        "[year repr:century]",
        "[year repr:century padding:none]",
        "[year repr:last_two padding:space]",
        "[year base:iso_week]",
        "[year base:iso_week repr:last_two]",
        "[year base:iso_week repr:century]",
        "[year sign:mandatory]",
        "[year repr:century sign:mandatory]",
        "[year repr:last_two sign:mandatory]",
        "[year range:standard]",
        "[year range:extended]",
        "[year range:bogus]",
        "[year padding:none]",
        "[year padding:space]",
        "[hour repr:12]",
        "[hour repr:24]",
        "[hour repr:12 padding:space]",
        "[hour repr:13]",
        "[minute]",
        "[minute padding:none]",
        "[second padding:space]",
        "[period]",
        "[period case:lower]",
        "[period case:upper case_sensitive:false]",
        "[subsecond]",
        "[subsecond digits:1]",
        "[subsecond digits:2]",
        "[subsecond digits:3]",
        "[subsecond digits:4]",
        "[subsecond digits:5]",
        "[subsecond digits:6]",
        "[subsecond digits:7]",
        "[subsecond digits:8]",
        "[subsecond digits:9]",
        "[subsecond digits:1+]",
        "[subsecond digits:10]",
        "[offset_hour]",
        "[offset_hour sign:mandatory padding:none]",
        "[offset_minute]",
        "[offset_second padding:space]",
        "[ignore]",
        "[ignore count:1]",
        "[ignore count:0]",
        "[ignore count:+3]",
        "[ignore count:-3]",
        "[ignore count:65535]",
        "[ignore count:65536]",
        "[ignore count:abc]",
        "[ignore padding:zero]",
        "[ignore count:2 count:3]",
        "[unix_timestamp]",
        "[unix_timestamp precision:millisecond]",
        "[unix_timestamp precision:microsecond sign:mandatory]",
        "[unix_timestamp precision:nanosecond]",
        "[end]",
        "[end trailing_input:discard]",
        "[end trailing_input:prohibit]",
        "[end trailing_input:x]",
        "abc",
        "",
        "a]b",
        "]",
        "\\[",
        "\\]",
        "\\\\",
        "\\a",
        "\\",
        "x\\",
        "[year]\\[[month]\\]",
        "[optional [[year]]]",
        "[optional [abc]]",
        "[optional [abc][def]]",
        "[optional]",
        "[optional ]",
        "[optional format:false [abc]]",
        "[optional format:true [abc]]",
        "[optional format:maybe [abc]]",
        "[optional foo:bar [abc]]",
        "[optional[abc]]",
        "[optional [abc] ]",
        "[optional [abc] [def]]",
        "[optional [[year] [month]]]",
        "[optional [[nothing]]]",
        "[optional [x",
        "[optional [x]",
        "[optional [x] y]",
        "[first [a][b]]",
        "[first [a] [b]]",
        "[first]",
        "[first ]",
        "[first [[year]] [[hour]]]",
        "[first [[hour]] [[year]]]",
        "[first x:y [a]]",
        "[first [] ]",
        "[first []]",
        "[first [a] ",
        "[year [abc]]",
        "[year [abc] ]",
        "[year[abc]]",
        "[hour[abc]]",
        "[a[",
        "[hour[",
        "[day]]",
        "[[day]]",
        "[\u{e9}]",
        "\u{e9}\u{e9}[nothing]",
        "\u{1F600}[day x:\u{e9}]",
        "[day \u{e9}:zero]",
        "[day padding:\u{e9}]",
        "[day\tpadding:space]",
        "[day\npadding:space]",
        "[day\u{0B}padding:space]",
        "[day padding:space\t]",
        "[ day ]",
        "[\tday]",
        "[day x]",
        "[day x:]",
        "[day :x]",
        "[day a:b:c]",
        "[optional [[day]] [[month]]]",
        "[optional  [abc]  ]",
        "[first  [abc]  [def]  ]",
        "[optional [abc]x]",
        "[optional [a\\]b]]",
        "[optional [a\\x]]",
        "[optional [[optional [[year]]]]]",
        "[first [[first [x] [y]]] [z]]",
        "[year]/[month repr:short]/[day padding:none] [hour repr:12]:[minute] [period case:lower]",
        "[weekday repr:short], [day] [month repr:short] [year] [hour]:[minute]:[second].[subsecond digits:3]",
    ]
    .into_iter()
    .map(String::from)
    .collect();
    let deep: String = "[optional [".repeat(130) + "x" + &"]]".repeat(130);
    patterns.push(deep);
    let deep2: String = "[a".repeat(260);
    patterns.push(deep2);
    let deep3: String = "[first [".repeat(128) + &"]]".repeat(128);
    patterns.push(deep3);

    let dates: Vec<Date> = vec![
        Date::from_calendar_date(2023, Month::April, 29).unwrap(),
        Date::from_calendar_date(2024, Month::February, 29).unwrap(),
        Date::from_calendar_date(2021, Month::January, 1).unwrap(),
        Date::from_calendar_date(2020, Month::December, 31).unwrap(),
        Date::from_calendar_date(2027, Month::January, 3).unwrap(),
        Date::from_calendar_date(1, Month::January, 1).unwrap(),
        Date::from_calendar_date(0, Month::March, 5).unwrap(),
        Date::from_calendar_date(-1, Month::June, 15).unwrap(),
        Date::from_calendar_date(-50, Month::June, 15).unwrap(),
        Date::from_calendar_date(-150, Month::June, 15).unwrap(),
        Date::from_calendar_date(-9999, Month::January, 1).unwrap(),
        Date::from_calendar_date(9999, Month::December, 31).unwrap(),
        Date::from_calendar_date(905, Month::September, 7).unwrap(),
    ];
    let times: Vec<Time> = vec![
        Time::from_hms(14, 26, 50).unwrap(),
        Time::from_hms(0, 0, 0).unwrap(),
        Time::from_hms(12, 0, 5).unwrap(),
        Time::from_hms(23, 59, 59).unwrap(),
        Time::from_hms_nano(1, 2, 3, 456_000_000).unwrap(),
        Time::from_hms_nano(9, 8, 7, 1).unwrap(),
        Time::from_hms_nano(11, 59, 0, 120_000).unwrap(),
    ];

    let mut out = String::new();
    out.push_str("// Generated by the Rust oracle harness (time 0.3.55). Do not edit.\n\n");

    // Format description parsing and formatting.
    out.push_str("///|\nlet oracle_patterns : Array[(String, String, String)] = [\n");
    for p in &patterns {
        let b = match format_description::parse_borrowed::<2>(p) {
            Ok(items) => {
                format!("ok:[{}]", items.iter().map(borrowed).collect::<Vec<_>>().join(","))
            }
            Err(e) => format!("err:{e}"),
        };
        let o = match format_description::parse_owned::<2>(p) {
            Ok(item) => format!("ok:{}", owned(&item)),
            Err(e) => format!("err:{e}"),
        };
        out.push_str(&format!("  ({}, {}, {}),\n", mbt_str(p), mbt_str(&b), mbt_str(&o)));
    }
    out.push_str("]\n\n");

    // Formatting: (pattern, kind, value-index, result)
    // Results are listed for all dates, then all times, then all datetimes.
    out.push_str("///|\nlet oracle_formats : Array[(String, Array[String])] = [\n");
    for p in &patterns {
        let Ok(item) = format_description::parse_owned::<2>(p) else { continue };
        let show = |r: Result<String, time::error::Format>| match r {
            Ok(s) => mbt_str(&format!("ok:{s}")),
            Err(e) => mbt_str(&format!("err:{e}")),
        };
        let mut results = vec![];
        for d in dates.iter() {
            results.push(show(d.format(&item)));
        }
        for t in times.iter() {
            results.push(show(t.format(&item)));
        }
        for (i, d) in dates.iter().enumerate() {
            let t = times[i % times.len()];
            let dt = PrimitiveDateTime::new(*d, t);
            results.push(show(dt.format(&item)));
        }
        out.push_str(&format!("  ({}, [{}]),\n", mbt_str(p), results.join(", ")));
    }
    out.push_str("]\n\n");

    // Dates: julian day -> properties.
    out.push_str("///|\nlet oracle_dates : Array[(Int, String)] = [\n");
    let mut jds: Vec<i32> = vec![];
    let min = Date::MIN.to_julian_day();
    let max = Date::MAX.to_julian_day();
    for jd in (min..=max).step_by(59_999) {
        jds.push(jd);
    }
    for jd in [min, min + 1, max, max - 1, 2460064, 2451545, 1721426, 1721425, 0, -1] {
        jds.push(jd);
    }
    for y in [1999, 2000, 2004, 2015, 2020, 2021, 2026, -4, -100, -400, 1900] {
        for (m, d) in [(1, 1), (1, 2), (1, 3), (1, 4), (12, 28), (12, 29), (12, 30), (12, 31), (2, 28), (3, 1)] {
            let date = Date::from_calendar_date(y, Month::try_from(m).unwrap(), d).unwrap();
            jds.push(date.to_julian_day());
        }
    }
    let durs: Vec<Duration> = vec![
        Duration::days(1),
        Duration::days(-1),
        Duration::days(400),
        Duration::days(-4000),
        Duration::hours(25),
        Duration::new(-86_399, -999_999_999),
        Duration::weeks(10_000_000),
    ];
    for jd in &jds {
        let d = Date::from_julian_day(*jd).unwrap();
        let mut s = format!(
            "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{:?}|{:?}",
            d.year(),
            d.month() as u8,
            d.day(),
            d.ordinal(),
            d.weekday().number_from_monday(),
            d.iso_week(),
            d.sunday_based_week(),
            d.monday_based_week(),
            d.to_julian_day(),
            d,
            d.to_iso_week_date().0,
            time::util::weeks_in_year(d.year()),
            d.next_day(),
            d.previous_day(),
        );
        for du in &durs {
            s.push_str(&format!("|{:?}|{:?}", d.checked_add(*du), d.checked_sub(*du)));
        }
        out.push_str(&format!("  ({jd}, {}),\n", mbt_str(&s)));
    }
    out.push_str("]\n\n");

    // Calendar date construction.
    out.push_str("///|\nlet oracle_calendar : Array[(Int, Int, Int, String)] = [\n");
    for y in [-10000, -9999, 0, 1900, 2000, 2023, 2024, 9999, 10000] {
        for m in 1..=12u8 {
            for d in [0u8, 1, 28, 29, 30, 31, 32] {
                let r = match Date::from_calendar_date(y, Month::try_from(m).unwrap(), d) {
                    Ok(d) => format!("ok:{d}"),
                    Err(e) => format!("err:{e}|{}", e.is_conditional()),
                };
                out.push_str(&format!("  ({y}, {m}, {d}, {}),\n", mbt_str(&r)));
            }
        }
    }
    out.push_str("]\n\n");

    // Durations from f64.
    out.push_str("///|\nlet oracle_f64 : Array[(UInt64, String)] = [\n");
    let mut fs: Vec<f64> = vec![
        0.0, -0.0, 1.0, -1.0, 0.5, 1.5, 0.1, 0.2, 0.3, 1e-9, 5e-10, 4.9e-10, 1.5e-9, 2.5e-9,
        0.999999999, 0.9999999995, 0.99999999949, 1.9999999995, 123456.789, -123456.789,
        1e10, 1e15, 1e16 + 0.5, 4.5e15, 9.2e18, -9.2e18, 9.3e18, -9.3e18,
        -9223372036854775808.0, 9223372036854775807.0, f64::NAN, f64::INFINITY,
        f64::NEG_INFINITY, 3600.0 * 1.5, 86400.0 / 7.0, 1e-20, 1e-300, 5e-324, 2.0f64.powi(-31),
        2.0f64.powi(-32), 2.0f64.powi(52), 2.0f64.powi(52) + 0.5, 2.0f64.powi(53), 2.0f64.powi(62),
        2.0f64.powi(63), 1.0 / 3.0, 2.0 / 3.0, 1e-10 * 7.0, 0.0000000015,
    ];
    let mut x: u64 = 0x1234_5678_9abc_def1;
    for _ in 0..300 {
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        let mant = (x >> 11) as f64 / (1u64 << 53) as f64;
        let e = ((x & 0x3f) as i32) - 32;
        let sign = if x & 0x40 != 0 { -1.0 } else { 1.0 };
        fs.push(sign * mant * 2.0f64.powi(e));
    }
    for f in &fs {
        let r = match Duration::checked_seconds_f64(*f) {
            Some(d) => format!("{}|{}|{}", d.whole_seconds(), d.subsec_nanoseconds(), d),
            None => format!("none|{:?}", Duration::saturating_seconds_f64(*f)),
        };
        out.push_str(&format!("  (0x{:x}UL, {}),\n", f.to_bits(), mbt_str(&r)));
    }
    out.push_str("]\n\n");

    // Time/PrimitiveDateTime arithmetic: (time-index, date-index, duration, result)
    out.push_str("///|\nlet oracle_arith : Array[(Int, Int, Int64, Int, String)] = [\n");
    let ad: Vec<Duration> = vec![
        Duration::ZERO,
        Duration::seconds(1),
        Duration::seconds(-1),
        Duration::nanoseconds(1),
        Duration::nanoseconds(-1),
        Duration::new(3599, 999_999_999),
        Duration::new(-3599, -999_999_999),
        Duration::hours(23),
        Duration::hours(-23),
        Duration::hours(24),
        Duration::days(366),
        Duration::new(-86_400 * 365 - 1, -500_000_000),
        Duration::new(123_456_789, 987_654_321),
        Duration::weeks(-600_000),
        Duration::new(i64::MAX, 999_999_999),
        Duration::new(i64::MIN, -999_999_999),
    ];
    for (ti, t) in times.iter().enumerate() {
        for (di, d) in dates.iter().enumerate() {
            if (ti + di) % 3 != 0 {
                continue;
            }
            for du in &ad {
                let dt = PrimitiveDateTime::new(*d, *t);
                let s = format!(
                    "{}|{}|{:?}|{:?}",
                    *t + *du,
                    *t - *du,
                    dt.checked_add(*du),
                    dt.checked_sub(*du)
                );
                out.push_str(&format!(
                    "  ({ti}, {di}, {}L, {}, {}),\n",
                    du.whole_seconds(),
                    du.subsec_nanoseconds(),
                    mbt_str(&s)
                ));
            }
        }
    }
    out.push_str("]\n\n");

    // Differences.
    out.push_str("///|\nlet oracle_diff : Array[(Int, Int, String)] = [\n");
    for i in 0..dates.len() {
        for j in 0..dates.len() {
            let a = PrimitiveDateTime::new(dates[i], times[i % times.len()]);
            let b = PrimitiveDateTime::new(dates[j], times[j % times.len()]);
            let s = format!(
                "{}|{}|{}|{:?}|{}",
                dates[i] - dates[j],
                times[i % times.len()] - times[j % times.len()],
                a - b,
                (a - b).whole_weeks(),
                times[i % times.len()].duration_until(times[j % times.len()]),
            );
            out.push_str(&format!("  ({i}, {j}, {}),\n", mbt_str(&s)));
        }
    }
    out.push_str("]\n\n");

    // Duration arithmetic (Typst's Duration repr uses these).
    out.push_str("///|\nlet oracle_duration_ops : Array[(Int64, Int, Double, String)] = [\n");
    let ds: Vec<Duration> = vec![
        Duration::new(0, 0),
        Duration::new(90061, 5),
        Duration::new(-90061, -5),
        Duration::new(1, 500_000_000),
        Duration::weeks(3) + Duration::days(2) + Duration::hours(5),
        Duration::new(-7, -999_999_999),
        Duration::seconds(-604_800 * 3 - 3_600),
    ];
    for d in &ds {
        for f in [1.0f64, 2.5, -0.5, 3.0, 1e-3, 7.0] {
            let s = format!(
                "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
                d,
                d.whole_weeks(),
                d.whole_days(),
                d.whole_hours(),
                d.whole_minutes(),
                d.whole_seconds(),
                d.subsec_nanoseconds(),
                d.as_seconds_f64().to_bits(),
                *d * f,
                *d / f,
                (*d / Duration::new(1, 250_000_000)).to_bits(),
                -*d,
                d.abs(),
            );
            out.push_str(&format!(
                "  ({}L, {}, {:?}, {}),\n",
                d.whole_seconds(),
                d.subsec_nanoseconds(),
                f,
                mbt_str(&s)
            ));
        }
    }
    out.push_str("]\n");

    print!("{out}");
}
