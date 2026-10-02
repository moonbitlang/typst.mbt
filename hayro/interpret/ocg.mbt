// Port of `hayro-interpret/src/ocg.rs`: optional content.

///|
priv struct OcgState {
  inactive_ocgs : @hashset.HashSet[@hayro_syntax.ObjectIdentifier]
  visibility_stack : Array[Bool]
}

///|
fn OcgState::dummy() -> OcgState {
  { inactive_ocgs: @hashset.new(), visibility_stack: [], }
}

///|
fn OcgState::default() -> OcgState {
  OcgState::dummy()
}

///|
fn OcgState::from_catalog(catalog : @hayro_syntax.Dict) -> OcgState {
  guard (catalog.get("OCProperties") : @hayro_syntax.Dict?)
    is Some(oc_properties) else {
    return OcgState::dummy()
  }
  guard (oc_properties.get("D") : @hayro_syntax.Dict?) is Some(config) else {
    return OcgState::dummy()
  }
  let inactive = @hashset.new()
  let base_state = match (config.get("BaseState") : @hayro_syntax.Name?) {
    Some(b) => BaseState::from_name(b.as_str())
    None => None
  }
  if base_state.unwrap_or(On) == Off &&
    (oc_properties.get("OCGs") : @hayro_syntax.PdfArray?) is Some(ocgs) {
    for item in ocgs.raw_iter() {
      if item.as_obj_ref() is Some(ref_) {
        inactive.add(ref_.to_id())
      }
    }
  }
  let read_ocg_array = (key : String, insert_active : Bool) => {
    if (config.get(key) : @hayro_syntax.PdfArray?) is Some(arr) {
      for item in arr.raw_iter() {
        if item.as_obj_ref() is Some(ref_) {
          let id = ref_.to_id()
          if insert_active {
            inactive.remove(id)
          } else {
            inactive.add(id)
          }
        }
      }
    }
  }
  read_ocg_array("ON", true)
  read_ocg_array("OFF", false)
  { inactive_ocgs: inactive, visibility_stack: [], }
}

///|
fn OcgState::begin_single_oc(
  self : OcgState,
  ocg_id : @hayro_syntax.ObjectIdentifier,
) -> Unit {
  let is_active = !self.inactive_ocgs.contains(ocg_id)
  let visible = self.is_visible() && is_active
  self.visibility_stack.push(visible)
}

///|
fn OcgState::begin_ocmd(self : OcgState, ocmd : @hayro_syntax.Dict) -> Unit {
  let policy = match (ocmd.get("P") : @hayro_syntax.Name?) {
    Some(n) => OcmdPolicy::from_name(n.as_str()).unwrap_or(AnyOn)
    None => AnyOn
  }
  let ocg_ids : Array[@hayro_syntax.ObjectIdentifier] = []
  if (ocmd.get("OCGs") : @hayro_syntax.PdfArray?) is Some(arr) {
    for item in arr.raw_iter() {
      if item.as_obj_ref() is Some(ref_) {
        ocg_ids.push(ref_.to_id())
      }
    }
  } else if ocmd.get_ref("OCGs") is Some(ref_) {
    ocg_ids.push(ref_.to_id())
  }
  let is_active = if ocg_ids.is_empty() {
    true
  } else {
    match policy {
      AllOn => ocg_ids.iter().all(id => !self.inactive_ocgs.contains(id))
      AnyOn => ocg_ids.iter().any(id => !self.inactive_ocgs.contains(id))
      AnyOff => ocg_ids.iter().any(id => self.inactive_ocgs.contains(id))
      AllOff => ocg_ids.iter().all(id => self.inactive_ocgs.contains(id))
    }
  }
  let visible = self.is_visible() && is_active
  self.visibility_stack.push(visible)
}

///|
fn OcgState::begin_ocg(
  self : OcgState,
  props : @hayro_syntax.Dict,
  ref_id : @hayro_syntax.ObjectIdentifier,
) -> Unit {
  match (props.get("Type") : @hayro_syntax.Name?) {
    Some(n) if n.as_str() == "OCMD" => self.begin_ocmd(props)
    _ => self.begin_single_oc(ref_id)
  }
}

///|
fn OcgState::begin_marked_content(self : OcgState) -> Unit {
  let visible = self.is_visible()
  self.visibility_stack.push(visible)
}

///|
fn OcgState::end_marked_content(self : OcgState) -> Unit {
  let _ = self.visibility_stack.pop()
}

///|
fn OcgState::is_visible(self : OcgState) -> Bool {
  self.visibility_stack.last().unwrap_or(true)
}

///|
priv enum BaseState {
  On
  Off
  Unchanged
} derive(Eq)

///|
fn BaseState::from_name(name : String) -> BaseState? {
  match name {
    "ON" => Some(On)
    "OFF" => Some(Off)
    "Unchanged" => Some(Unchanged)
    _ => None
  }
}

///|
priv enum OcmdPolicy {
  AllOn
  AnyOn
  AnyOff
  AllOff
} derive(Eq)

///|
fn OcmdPolicy::from_name(name : String) -> OcmdPolicy? {
  match name {
    "AllOn" => Some(AllOn)
    "AnyOn" => Some(AnyOn)
    "AnyOff" => Some(AnyOff)
    "AllOff" => Some(AllOff)
    _ => None
  }
}
