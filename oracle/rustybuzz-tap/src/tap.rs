//! Records the inputs and outputs of every `shape_with_plan` call.

extern crate std;

use alloc::string::String;
use alloc::vec::Vec;
use std::sync::Mutex;

use crate::hb::face::hb_font_t;
use crate::hb::ot_shape_plan::hb_ot_shape_plan_t;
use crate::{Direction, Feature, GlyphBuffer, Language, Script, UnicodeBuffer};

/// A reusable plan for shaping a text buffer (rustybuzz's `ShapePlan`, plus
/// the parameters it was created with).
pub struct ShapePlan {
    inner: hb_ot_shape_plan_t,
    direction: Direction,
    script: Option<Script>,
    language: Option<Language>,
    features: Vec<Feature>,
}

impl ShapePlan {
    /// Returns a plan that can be used for shaping any buffer with the
    /// provided properties.
    pub fn new(
        face: &hb_font_t,
        direction: Direction,
        script: Option<Script>,
        language: Option<&Language>,
        user_features: &[Feature],
    ) -> Self {
        Self {
            inner: hb_ot_shape_plan_t::new(face, direction, script, language, user_features),
            direction,
            script,
            language: language.cloned(),
            features: user_features.to_vec(),
        }
    }
}

/// One recorded shaping call.
#[derive(Clone, Debug)]
pub struct TapRecord {
    /// Address and length of the face's data (identifies the font).
    pub data: (usize, usize),
    /// Normalized variation coordinates of the face.
    pub coords: Vec<i16>,
    /// Plan parameters.
    pub direction: Direction,
    pub script: Option<Script>,
    pub language: Option<String>,
    pub features: Vec<Feature>,
    /// Buffer properties before shaping (after guessing).
    pub buffer_direction: Direction,
    pub buffer_script: Option<Script>,
    pub buffer_language: Option<String>,
    pub flags: u32,
    pub cluster_level: u32,
    pub pre_context: Vec<char>,
    pub post_context: Vec<char>,
    /// Input codepoints with their clusters.
    pub input: Vec<(char, u32)>,
    /// Output: glyph id, cluster, glyph flags, x/y advance, x/y offset.
    pub output: Vec<(u32, u32, u32, i32, i32, i32, i32)>,
}

static RECORDS: Mutex<Option<Vec<TapRecord>>> = Mutex::new(None);

/// Start recording (clears previously recorded calls).
pub fn start_recording() {
    *RECORDS.lock().unwrap() = Some(Vec::new());
}

/// Stop recording and return the recorded calls.
pub fn take_records() -> Vec<TapRecord> {
    RECORDS.lock().unwrap().take().unwrap_or_default()
}

/// Shapes the buffer content using the provided font and plan.
pub fn shape_with_plan(face: &hb_font_t, plan: &ShapePlan, buffer: UnicodeBuffer) -> GlyphBuffer {
    let recording = RECORDS.lock().unwrap().is_some();
    if !recording {
        return crate::hb::shape::shape_with_plan(face, &plan.inner, buffer);
    }

    let mut buffer = buffer;
    let b = &mut buffer.0;
    // `shape_with_plan` guesses first, so record the guessed properties.
    b.guess_segment_properties();
    let raw = face.raw_face().data;
    let mut record = TapRecord {
        data: (raw.as_ptr() as usize, raw.len()),
        coords: face.variation_coordinates().iter().map(|c| c.get()).collect(),
        direction: plan.direction,
        script: plan.script,
        language: plan.language.as_ref().map(|l| l.as_str().into()),
        features: plan.features.clone(),
        buffer_direction: b.direction,
        buffer_script: b.script,
        buffer_language: b.language.as_ref().map(|l| l.as_str().into()),
        flags: b.flags.bits(),
        cluster_level: b.cluster_level,
        pre_context: b.context[0][..b.context_len[0]].to_vec(),
        post_context: b.context[1][..b.context_len[1]].to_vec(),
        input: b.info[..b.len].iter().map(|i| (i.as_char(), i.cluster)).collect(),
        output: Vec::new(),
    };

    let out = crate::hb::shape::shape_with_plan(face, &plan.inner, buffer);
    record.output = out
        .glyph_infos()
        .iter()
        .zip(out.glyph_positions())
        .map(|(i, p)| {
            (
                i.glyph_id,
                i.cluster,
                i.mask & crate::hb::buffer::glyph_flag::DEFINED,
                p.x_advance,
                p.y_advance,
                p.x_offset,
                p.y_offset,
            )
        })
        .collect();

    if let Some(records) = RECORDS.lock().unwrap().as_mut() {
        records.push(record);
    }
    out
}
