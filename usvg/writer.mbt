// Port of `usvg` 0.47.0 `src/writer.rs`: writes a `Tree` back to SVG.

///|
/// XML writing options.
pub(all) struct WriteOptions {
  /// Used to add a custom prefix to each element ID during writing.
  id_prefix : String?
  /// Do not convert text into paths.
  ///
  /// Default: false
  preserve_text : Bool
  /// Set the coordinates numeric precision.
  ///
  /// Smaller precision can lead to a malformed output in some cases.
  ///
  /// Default: 8
  coordinates_precision : Int
  /// Set the transform values numeric precision.
  ///
  /// Smaller precision can lead to a malformed output in some cases.
  ///
  /// Default: 8
  transforms_precision : Int
  /// Use single quote marks instead of double quote.
  ///
  /// Default: disabled
  use_single_quote : Bool
  /// Set XML nodes indention.
  ///
  /// Default: 4 spaces
  indent : @xmlwriter.Indent
  /// Set XML attributes indention.
  ///
  /// Default: `None`
  attributes_indent : @xmlwriter.Indent
}

///|
pub impl Default for WriteOptions with fn default() {
  {
    id_prefix: None,
    preserve_text: false,
    coordinates_precision: 8,
    transforms_precision: 8,
    use_single_quote: false,
    indent: Spaces(4),
    attributes_indent: None,
  }
}

///|
/// Writes `usvg::Tree` back to SVG.
pub fn Tree::to_string(self : Tree, opt : WriteOptions) -> String {
  writer_convert(self, opt)
}

///|
fn writer_convert(tree : Tree, opt : WriteOptions) -> String {
  let xml = @xmlwriter.XmlWriter::new({
    use_single_quote: opt.use_single_quote,
    indent: opt.indent,
    attributes_indent: opt.attributes_indent,
  })
  xml.start_svg_element(EId::Svg)
  xml.write_svg_attribute(AId::Width, rust_display_f32(tree.size.width()))
  xml.write_svg_attribute(AId::Height, rust_display_f32(tree.size.height()))
  xml.write_attribute("xmlns", "http://www.w3.org/2000/svg")
  if has_xlink(tree.root) {
    xml.write_attribute("xmlns:xlink", "http://www.w3.org/1999/xlink")
  }
  let has_text_paths = has_text_paths(tree.root)
  if tree.has_defs_nodes() || has_text_paths {
    write_defs(tree, opt, xml, has_text_paths)
  }
  write_elements(tree.root, false, opt, xml)
  xml.end_document()
}

///|
fn write_filters(
  tree : Tree,
  opt : WriteOptions,
  xml : @xmlwriter.XmlWriter,
) -> Unit {
  let written_fe_image_nodes : Array[String] = []
  for filter in tree.filters {
    for fe in filter.primitives {
      if fe.kind is Image(img) {
        if img.root.children.get(0) is Some(child) {
          if !written_fe_image_nodes.iter().any(id => id == child.id()) {
            write_element(child, false, opt, xml)
            written_fe_image_nodes.push(child.id())
          }
        }
      }
    }
    xml.start_svg_element(EId::Filter)
    xml.write_id_attribute(filter.id(), opt)
    xml.write_rect_attrs(filter.rect)
    xml.write_units(AId::FilterUnits, UserSpaceOnUse, ObjectBoundingBox)
    for fe in filter.primitives {
      match fe.kind {
        DropShadow(shadow) => {
          xml.start_svg_element(EId::FeDropShadow)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          xml.write_filter_input(AId::In, shadow.input)
          xml.write_attribute(
            AId::StdDeviation.to_str(),
            "\{rust_display_f32(shadow.std_dev_x.get())} \{rust_display_f32(shadow.std_dev_y.get())}",
          )
          xml.write_svg_attribute(AId::Dx, rust_display_f32(shadow.dx))
          xml.write_svg_attribute(AId::Dy, rust_display_f32(shadow.dy))
          xml.write_color(AId::FloodColor, shadow.color)
          xml.write_svg_attribute(
            AId::FloodOpacity,
            rust_display_f32(shadow.opacity.get()),
          )
          xml.write_svg_attribute(AId::Result, fe.result)
          xml.end_element()
        }
        GaussianBlur(blur) => {
          xml.start_svg_element(EId::FeGaussianBlur)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          xml.write_filter_input(AId::In, blur.input)
          xml.write_attribute(
            AId::StdDeviation.to_str(),
            "\{rust_display_f32(blur.std_dev_x.get())} \{rust_display_f32(blur.std_dev_y.get())}",
          )
          xml.write_svg_attribute(AId::Result, fe.result)
          xml.end_element()
        }
        Offset(offset) => {
          xml.start_svg_element(EId::FeOffset)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          xml.write_filter_input(AId::In, offset.input)
          xml.write_svg_attribute(AId::Dx, rust_display_f32(offset.dx))
          xml.write_svg_attribute(AId::Dy, rust_display_f32(offset.dy))
          xml.write_svg_attribute(AId::Result, fe.result)
          xml.end_element()
        }
        Blend(blend) => {
          xml.start_svg_element(EId::FeBlend)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          xml.write_filter_input(AId::In, blend.input1)
          xml.write_filter_input(AId::In2, blend.input2)
          xml.write_svg_attribute(AId::Mode, blend.mode.to_string())
          xml.write_svg_attribute(AId::Result, fe.result)
          xml.end_element()
        }
        Flood(flood) => {
          xml.start_svg_element(EId::FeFlood)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          xml.write_color(AId::FloodColor, flood.color)
          xml.write_svg_attribute(
            AId::FloodOpacity,
            rust_display_f32(flood.opacity.get()),
          )
          xml.write_svg_attribute(AId::Result, fe.result)
          xml.end_element()
        }
        Composite(composite) => {
          xml.start_svg_element(EId::FeComposite)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          xml.write_filter_input(AId::In, composite.input1)
          xml.write_filter_input(AId::In2, composite.input2)
          xml.write_svg_attribute(
            AId::Operator,
            match composite.operator {
              Over => "over"
              In => "in"
              Out => "out"
              Atop => "atop"
              Xor => "xor"
              Arithmetic(..) => "arithmetic"
            },
          )
          if composite.operator is Arithmetic(k1~, k2~, k3~, k4~) {
            xml.write_svg_attribute(AId::K1, rust_display_f32(k1))
            xml.write_svg_attribute(AId::K2, rust_display_f32(k2))
            xml.write_svg_attribute(AId::K3, rust_display_f32(k3))
            xml.write_svg_attribute(AId::K4, rust_display_f32(k4))
          }
          xml.write_svg_attribute(AId::Result, fe.result)
          xml.end_element()
        }
        Merge(merge) => {
          xml.start_svg_element(EId::FeMerge)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          xml.write_svg_attribute(AId::Result, fe.result)
          for input in merge.inputs {
            xml.start_svg_element(EId::FeMergeNode)
            xml.write_filter_input(AId::In, input)
            xml.end_element()
          }
          xml.end_element()
        }
        Tile(tile) => {
          xml.start_svg_element(EId::FeTile)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          xml.write_filter_input(AId::In, tile.input)
          xml.write_svg_attribute(AId::Result, fe.result)
          xml.end_element()
        }
        Image(img) => {
          xml.start_svg_element(EId::FeImage)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          if img.root.children.get(0) is Some(child) {
            let prefix = opt.id_prefix.unwrap_or("")
            xml.write_attribute("xlink:href", "#\{prefix}\{child.id()}")
          }
          xml.write_svg_attribute(AId::Result, fe.result)
          xml.end_element()
        }
        ComponentTransfer(transfer) => {
          xml.start_svg_element(EId::FeComponentTransfer)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          xml.write_filter_input(AId::In, transfer.input)
          xml.write_svg_attribute(AId::Result, fe.result)
          xml.write_filter_transfer_function(EId::FeFuncR, transfer.func_r)
          xml.write_filter_transfer_function(EId::FeFuncG, transfer.func_g)
          xml.write_filter_transfer_function(EId::FeFuncB, transfer.func_b)
          xml.write_filter_transfer_function(EId::FeFuncA, transfer.func_a)
          xml.end_element()
        }
        ColorMatrix(matrix) => {
          xml.start_svg_element(EId::FeColorMatrix)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          xml.write_filter_input(AId::In, matrix.input)
          xml.write_svg_attribute(AId::Result, fe.result)
          match matrix.kind {
            Matrix(values) => {
              xml.write_svg_attribute(AId::Type, "matrix")
              xml.write_numbers(AId::Values, values)
            }
            Saturate(value) => {
              xml.write_svg_attribute(AId::Type, "saturate")
              xml.write_svg_attribute(
                AId::Values,
                rust_display_f32(value.get()),
              )
            }
            HueRotate(angle) => {
              xml.write_svg_attribute(AId::Type, "hueRotate")
              xml.write_svg_attribute(AId::Values, rust_display_f32(angle))
            }
            LuminanceToAlpha =>
              xml.write_svg_attribute(AId::Type, "luminanceToAlpha")
          }
          xml.end_element()
        }
        ConvolveMatrix(matrix) => {
          xml.start_svg_element(EId::FeConvolveMatrix)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          xml.write_filter_input(AId::In, matrix.input)
          xml.write_svg_attribute(AId::Result, fe.result)
          xml.write_attribute(
            AId::Order.to_str(),
            "\{matrix.matrix.columns} \{matrix.matrix.rows}",
          )
          xml.write_numbers(AId::KernelMatrix, matrix.matrix.data)
          xml.write_svg_attribute(
            AId::Divisor,
            rust_display_f32(matrix.divisor.get()),
          )
          xml.write_svg_attribute(AId::Bias, rust_display_f32(matrix.bias))
          xml.write_svg_attribute(
            AId::TargetX,
            matrix.matrix.target_x.to_string(),
          )
          xml.write_svg_attribute(
            AId::TargetY,
            matrix.matrix.target_y.to_string(),
          )
          xml.write_svg_attribute(
            AId::EdgeMode,
            match matrix.edge_mode {
              EdgeNone => "none"
              Duplicate => "duplicate"
              Wrap => "wrap"
            },
          )
          xml.write_svg_attribute(
            AId::PreserveAlpha,
            if matrix.preserve_alpha {
              "true"
            } else {
              "false"
            },
          )
          xml.end_element()
        }
        Morphology(morphology) => {
          xml.start_svg_element(EId::FeMorphology)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          xml.write_filter_input(AId::In, morphology.input)
          xml.write_svg_attribute(AId::Result, fe.result)
          xml.write_svg_attribute(
            AId::Operator,
            match morphology.operator {
              Erode => "erode"
              Dilate => "dilate"
            },
          )
          xml.write_attribute(
            AId::Radius.to_str(),
            "\{rust_display_f32(morphology.radius_x.get())} \{rust_display_f32(morphology.radius_y.get())}",
          )
          xml.end_element()
        }
        DisplacementMap(map) => {
          xml.start_svg_element(EId::FeDisplacementMap)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          xml.write_filter_input(AId::In, map.input1)
          xml.write_filter_input(AId::In2, map.input2)
          xml.write_svg_attribute(AId::Result, fe.result)
          xml.write_svg_attribute(AId::Scale, rust_display_f32(map.scale))
          let write_channel = (c : ColorChannel, aid : AId) => {
            xml.write_svg_attribute(
              aid,
              match c {
                R => "R"
                G => "G"
                B => "B"
                A => "A"
              },
            )
          }
          write_channel(map.x_channel_selector, AId::XChannelSelector)
          write_channel(map.y_channel_selector, AId::YChannelSelector)
          xml.end_element()
        }
        Turbulence(turbulence) => {
          xml.start_svg_element(EId::FeTurbulence)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          xml.write_svg_attribute(AId::Result, fe.result)
          xml.write_attribute(
            AId::BaseFrequency.to_str(),
            "\{rust_display_f32(turbulence.base_frequency_x.get())} \{rust_display_f32(turbulence.base_frequency_y.get())}",
          )
          xml.write_svg_attribute(
            AId::NumOctaves,
            turbulence.num_octaves.to_string(),
          )
          xml.write_svg_attribute(AId::Seed, turbulence.seed.to_string())
          xml.write_svg_attribute(
            AId::StitchTiles,
            if turbulence.stitch_tiles {
              "stitch"
            } else {
              "noStitch"
            },
          )
          xml.write_svg_attribute(
            AId::Type,
            match turbulence.kind {
              FractalNoise => "fractalNoise"
              Turbulence => "turbulence"
            },
          )
          xml.end_element()
        }
        DiffuseLighting(light) => {
          xml.start_svg_element(EId::FeDiffuseLighting)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          xml.write_svg_attribute(AId::Result, fe.result)
          xml.write_svg_attribute(
            AId::SurfaceScale,
            rust_display_f32(light.surface_scale),
          )
          xml.write_svg_attribute(
            AId::DiffuseConstant,
            rust_display_f32(light.diffuse_constant),
          )
          xml.write_color(AId::LightingColor, light.lighting_color)
          write_light_source(light.light_source, xml)
          xml.end_element()
        }
        SpecularLighting(light) => {
          xml.start_svg_element(EId::FeSpecularLighting)
          xml.write_filter_primitive_attrs(filter.rect, fe)
          xml.write_svg_attribute(AId::Result, fe.result)
          xml.write_svg_attribute(
            AId::SurfaceScale,
            rust_display_f32(light.surface_scale),
          )
          xml.write_svg_attribute(
            AId::SpecularConstant,
            rust_display_f32(light.specular_constant),
          )
          xml.write_svg_attribute(
            AId::SpecularExponent,
            rust_display_f32(light.specular_exponent),
          )
          xml.write_color(AId::LightingColor, light.lighting_color)
          write_light_source(light.light_source, xml)
          xml.end_element()
        }
      }
    }
    xml.end_element()
  }
}

///|
fn write_defs(
  tree : Tree,
  opt : WriteOptions,
  xml : @xmlwriter.XmlWriter,
  write_text_paths : Bool,
) -> Unit {
  xml.start_svg_element(EId::Defs)
  for lg in tree.linear_gradients {
    xml.start_svg_element(EId::LinearGradient)
    xml.write_id_attribute(lg.id(), opt)
    xml.write_svg_attribute(AId::X1, rust_display_f32(lg.x1))
    xml.write_svg_attribute(AId::Y1, rust_display_f32(lg.y1))
    xml.write_svg_attribute(AId::X2, rust_display_f32(lg.x2))
    xml.write_svg_attribute(AId::Y2, rust_display_f32(lg.y2))
    write_base_grad(lg.base, opt, xml)
    xml.end_element()
  }
  for rg in tree.radial_gradients {
    xml.start_svg_element(EId::RadialGradient)
    xml.write_id_attribute(rg.id(), opt)
    xml.write_svg_attribute(AId::Cx, rust_display_f32(rg.cx))
    xml.write_svg_attribute(AId::Cy, rust_display_f32(rg.cy))
    xml.write_svg_attribute(AId::R, rust_display_f32(rg.r.get()))
    xml.write_svg_attribute(AId::Fx, rust_display_f32(rg.fx))
    xml.write_svg_attribute(AId::Fy, rust_display_f32(rg.fy))
    write_base_grad(rg.base, opt, xml)
    xml.end_element()
  }
  for pattern in tree.patterns {
    xml.start_svg_element(EId::Pattern)
    xml.write_id_attribute(pattern.id(), opt)
    xml.write_rect_attrs(pattern.rect)
    xml.write_units(AId::PatternUnits, pattern.units, ObjectBoundingBox)
    xml.write_units(
      AId::PatternContentUnits,
      pattern.content_units,
      UserSpaceOnUse,
    )
    xml.write_transform(AId::PatternTransform, pattern.transform, opt)
    write_elements(pattern.root, false, opt, xml)
    xml.end_element()
  }
  if write_text_paths {
    write_text_path_paths(tree.root, opt, xml)
  }
  write_filters(tree, opt, xml)
  for clip in tree.clip_paths {
    xml.start_svg_element(EId::ClipPath)
    xml.write_id_attribute(clip.id(), opt)
    xml.write_transform(AId::Transform, clip.transform, opt)
    if clip.clip_path is Some(clip) {
      xml.write_func_iri(AId::ClipPath, clip.id(), opt)
    }
    write_elements(clip.root, true, opt, xml)
    xml.end_element()
  }
  for mask in tree.masks {
    xml.start_svg_element(EId::Mask)
    xml.write_id_attribute(mask.id(), opt)
    if mask.kind == Alpha {
      xml.write_svg_attribute(AId::MaskType, "alpha")
    }
    xml.write_units(AId::MaskUnits, UserSpaceOnUse, ObjectBoundingBox)
    xml.write_rect_attrs(mask.rect)
    if mask.mask is Some(mask) {
      xml.write_func_iri(AId::Mask, mask.id(), opt)
    }
    write_elements(mask.root, false, opt, xml)
    xml.end_element()
  }
  xml.end_element() // end EId::Defs
}

///|
fn has_text_paths(parent : Group) -> Bool {
  for node in parent.children {
    if node is Group(group) {
      if has_text_paths(group) {
        return true
      }
    } else if node is Text(text) {
      for chunk in text.chunks {
        if chunk.text_flow is Path(text_path) {
          let path = Path::new(
            text_path.id(),
            true,
            None,
            None,
            PaintOrder::default(),
            ShapeRendering::default(),
            text_path.path,
            Transform::default(),
          )
          if path is Some(_) {
            return true
          }
        }
      }
    }
    let mut need_path = false
    node.subroots(subroot => {
      if !need_path && has_text_paths(subroot) {
        need_path = true
      }
    })
    if need_path {
      return true
    }
  }
  false
}

///|
/// Write the `path` elements for text paths.
fn write_text_path_paths(
  parent : Group,
  opt : WriteOptions,
  xml : @xmlwriter.XmlWriter,
) -> Unit {
  for node in parent.children {
    if node is Group(group) {
      write_text_path_paths(group, opt, xml)
    } else if node is Text(text) {
      for chunk in text.chunks {
        if chunk.text_flow is Path(text_path) {
          let path = Path::new(
            text_path.id(),
            true,
            None,
            None,
            PaintOrder::default(),
            ShapeRendering::default(),
            text_path.path,
            Transform::default(),
          )
          if path is Some(path) {
            write_path(path, false, Transform::default(), None, opt, xml)
          }
        }
      }
    }
    node.subroots(subroot => write_text_path_paths(subroot, opt, xml))
  }
}

///|
fn write_elements(
  parent : Group,
  is_clip_path : Bool,
  opt : WriteOptions,
  xml : @xmlwriter.XmlWriter,
) -> Unit {
  for n in parent.children {
    write_element(n, is_clip_path, opt, xml)
  }
}

///|
fn write_element(
  node : Node,
  is_clip_path : Bool,
  opt : WriteOptions,
  xml : @xmlwriter.XmlWriter,
) -> Unit {
  match node {
    Path(p) => write_path(p, is_clip_path, Transform::default(), None, opt, xml)
    Image(img) => {
      xml.start_svg_element(EId::Image)
      if !img.id.is_empty() {
        xml.write_id_attribute(img.id, opt)
      }
      xml.write_svg_attribute(AId::Width, rust_display_f32(img.size.width()))
      xml.write_svg_attribute(AId::Height, rust_display_f32(img.size.height()))
      xml.write_visibility(img.visible)
      match img.rendering_mode {
        OptimizeQuality => ()
        OptimizeSpeed =>
          xml.write_svg_attribute(AId::ImageRendering, "optimizeSpeed")
        Smooth =>
          xml.write_attribute(AId::Style.to_str(), "image-rendering:smooth")
        HighQuality =>
          xml.write_attribute(
            AId::Style.to_str(),
            "image-rendering:high-quality",
          )
        CrispEdges =>
          xml.write_attribute(
            AId::Style.to_str(),
            "image-rendering:crisp-edges",
          )
        Pixelated =>
          xml.write_attribute(AId::Style.to_str(), "image-rendering:pixelated")
      }
      xml.write_image_data(img.kind)
      xml.end_element()
    }
    Group(g) => write_group_element(g, is_clip_path, opt, xml)
    Text(text) =>
      if opt.preserve_text {
        xml.start_svg_element(EId::Text)
        if !text.id.is_empty() {
          xml.write_id_attribute(text.id, opt)
        }
        xml.write_attribute("xml:space", "preserve")
        match text.writing_mode {
          LeftToRight => ()
          TopToBottom => xml.write_svg_attribute(AId::WritingMode, "tb")
        }
        match text.rendering_mode {
          OptimizeSpeed =>
            xml.write_svg_attribute(AId::TextRendering, "optimizeSpeed")
          GeometricPrecision =>
            xml.write_svg_attribute(AId::TextRendering, "geometricPrecision")
          OptimizeLegibility => ()
        }
        if text.rotate.iter().any(r => r != 0.0) {
          xml.write_numbers(AId::Rotate, text.rotate)
        }
        if text.dx.iter().any(dx => dx != 0.0) {
          xml.write_numbers(AId::Dx, text.dx)
        }
        if text.dy.iter().any(dy => dy != 0.0) {
          xml.write_numbers(AId::Dy, text.dy)
        }
        xml.set_preserve_whitespaces(true)
        for chunk in text.chunks {
          if chunk.text_flow is Path(text_path) {
            xml.start_svg_element(EId::TextPath)
            let prefix = opt.id_prefix.unwrap_or("")
            xml.write_attribute("xlink:href", "#\{prefix}\{text_path.id()}")
            if text_path.start_offset != 0.0 {
              xml.write_svg_attribute(
                AId::StartOffset,
                rust_display_f32(text_path.start_offset),
              )
            }
          }
          xml.start_svg_element(EId::Tspan)
          if chunk.x is Some(x) {
            xml.write_svg_attribute(AId::X, rust_display_f32(x))
          }
          if chunk.y is Some(y) {
            xml.write_svg_attribute(AId::Y, rust_display_f32(y))
          }
          match chunk.anchor {
            Start => ()
            Middle => xml.write_svg_attribute(AId::TextAnchor, "middle")
            End => xml.write_svg_attribute(AId::TextAnchor, "end")
          }
          for span in chunk.spans {
            let decorations = []
            if span.decoration.underline is Some(value) {
              decorations.push(("underline", value))
            }
            if span.decoration.line_through is Some(value) {
              decorations.push(("line-through", value))
            }
            if span.decoration.overline is Some(value) {
              decorations.push(("overline", value))
            }

            // Decorations need to be dumped BEFORE we write the actual span data
            // (so that for example stroke color of span doesn't affect the text
            // itself while baseline shifts need to be written after (since they are
            // affected by the font size)
            for item in decorations {
              let (deco_name, deco) = item
              xml.start_svg_element(EId::Tspan)
              xml.write_svg_attribute(AId::TextDecoration, deco_name)
              write_fill(deco.fill, false, opt, xml)
              write_stroke(deco.stroke, opt, xml)
            }
            write_span(is_clip_path, opt, xml, chunk, span)

            // End for each tspan we needed to create for decorations
            for _ in decorations {
              xml.end_element()
            }
          }
          xml.end_element()

          // End textPath element
          if chunk.text_flow is Path(_) {
            xml.end_element()
          }
        }
        xml.end_element()
        xml.set_preserve_whitespaces(false)
      } else {
        write_group_element(text.flattened, is_clip_path, opt, xml)
      }
  }
}

///|
fn write_group_element(
  g : Group,
  is_clip_path : Bool,
  opt : WriteOptions,
  xml : @xmlwriter.XmlWriter,
) -> Unit {
  if is_clip_path {
    // The `clipPath` element in SVG doesn't allow groups, only shapes and text.
    // The problem is that in `usvg` we can set a `clip-path` only on groups.
    // So in cases when a `clipPath` child has a `clip-path` as well,
    // it would be inside a group. And we have to skip this group during writing.
    //
    // Basically, the following SVG:
    //
    // <clipPath id="clip">
    //   <path clip-path="url(#clip-nested)"/>
    // </clipPath>
    //
    // will be represented in usvg as:
    //
    // <clipPath id="clip">
    //   <g clip-path="url(#clip-nested)">
    //      <path/>
    //   </g>
    // </clipPath>
    //
    //
    // Same with text. Text elements will be converted into groups,
    // but only the group's children should be written.
    for child in g.children {
      match child {
        Group(child_group) =>
          write_group_element(child_group, is_clip_path, opt, xml)
        Path(child_path) => {
          let clip_id = g.clip_path.map(cp => cp.id())
          write_path(child_path, is_clip_path, g.transform, clip_id, opt, xml)
        }
        _ => ()
      }
    }
    return
  }
  xml.start_svg_element(EId::G)
  if !g.id.is_empty() {
    xml.write_id_attribute(g.id, opt)
  }
  if g.clip_path is Some(clip) {
    xml.write_func_iri(AId::ClipPath, clip.id(), opt)
  }
  if g.mask is Some(mask) {
    xml.write_func_iri(AId::Mask, mask.id(), opt)
  }
  if !g.filters.is_empty() {
    let prefix = opt.id_prefix.unwrap_or("")
    let ids = g.filters.map(filter => "url(#\{prefix}\{filter.id()})")
    xml.write_svg_attribute(AId::Filter, ids.join(" "))
  }
  if g.opacity != Opacity::one() {
    xml.write_svg_attribute(AId::Opacity, rust_display_f32(g.opacity.get()))
  }
  xml.write_transform(AId::Transform, g.transform, opt)
  if g.blend_mode != BlendMode::Normal || g.isolate {
    // For reasons unknown, `mix-blend-mode` and `isolation` must be written
    // as `style` attribute.
    let isolation = if g.isolate { "isolate" } else { "auto" }
    xml.write_attribute(
      AId::Style.to_str(),
      "mix-blend-mode:\{g.blend_mode};isolation:\{isolation}",
    )
  }
  write_elements(g, false, opt, xml)
  xml.end_element()
}

///|
fn @xmlwriter.XmlWriter::start_svg_element(
  self : @xmlwriter.XmlWriter,
  id : EId,
) -> Unit {
  self.start_element(id.to_str())
}

///|
fn @xmlwriter.XmlWriter::write_svg_attribute(
  self : @xmlwriter.XmlWriter,
  id : AId,
  value : String,
) -> Unit {
  self.write_attribute(id.to_str(), value)
}

///|
fn @xmlwriter.XmlWriter::write_id_attribute(
  self : @xmlwriter.XmlWriter,
  id : String,
  opt : WriteOptions,
) -> Unit {
  if opt.id_prefix is Some(prefix) {
    let full_id = "\{prefix}\{id}"
    self.write_attribute("id", full_id)
  } else {
    self.write_attribute("id", id)
  }
}

///|
fn @xmlwriter.XmlWriter::write_color(
  self : @xmlwriter.XmlWriter,
  id : AId,
  c : Color,
) -> Unit {
  let chars = "0123456789abcdef"
  let buf = StringBuilder()
  buf.write_char('#')
  for n in [c.red, c.green, c.blue] {
    buf.write_char(chars.unsafe_get(n >> 4).unsafe_to_char())
    buf.write_char(chars.unsafe_get(n & 0xf).unsafe_to_char())
  }
  self.write_attribute(id.to_str(), buf.to_string())
}

///|
// TODO: simplify
fn @xmlwriter.XmlWriter::write_units(
  self : @xmlwriter.XmlWriter,
  id : AId,
  units : Units,
  def : Units,
) -> Unit {
  if units != def {
    self.write_attribute(
      id.to_str(),
      match units {
        UserSpaceOnUse => "userSpaceOnUse"
        ObjectBoundingBox => "objectBoundingBox"
      },
    )
  }
}

///|
fn @xmlwriter.XmlWriter::write_transform(
  self : @xmlwriter.XmlWriter,
  id : AId,
  ts : Transform,
  opt : WriteOptions,
) -> Unit {
  if ts != Transform::default() {
    let buf = StringBuilder()
    buf.write_string("matrix(")
    write_num(ts.sx, buf, opt.transforms_precision)
    buf.write_char(' ')
    write_num(ts.ky, buf, opt.transforms_precision)
    buf.write_char(' ')
    write_num(ts.kx, buf, opt.transforms_precision)
    buf.write_char(' ')
    write_num(ts.sy, buf, opt.transforms_precision)
    buf.write_char(' ')
    write_num(ts.tx, buf, opt.transforms_precision)
    buf.write_char(' ')
    write_num(ts.ty, buf, opt.transforms_precision)
    buf.write_string(")")
    self.write_attribute(id.to_str(), buf.to_string())
  }
}

///|
fn @xmlwriter.XmlWriter::write_visibility(
  self : @xmlwriter.XmlWriter,
  value : Bool,
) -> Unit {
  if !value {
    self.write_attribute(AId::Visibility.to_str(), "hidden")
  }
}

///|
fn @xmlwriter.XmlWriter::write_func_iri(
  self : @xmlwriter.XmlWriter,
  aid : AId,
  id : String,
  opt : WriteOptions,
) -> Unit {
  let prefix = opt.id_prefix.unwrap_or("")
  self.write_attribute(aid.to_str(), "url(#\{prefix}\{id})")
}

///|
fn @xmlwriter.XmlWriter::write_rect_attrs(
  self : @xmlwriter.XmlWriter,
  r : NonZeroRect,
) -> Unit {
  self.write_svg_attribute(AId::X, rust_display_f32(r.x()))
  self.write_svg_attribute(AId::Y, rust_display_f32(r.y()))
  self.write_svg_attribute(AId::Width, rust_display_f32(r.width()))
  self.write_svg_attribute(AId::Height, rust_display_f32(r.height()))
}

///|
fn @xmlwriter.XmlWriter::write_numbers(
  self : @xmlwriter.XmlWriter,
  aid : AId,
  list : Array[Float],
) -> Unit {
  self.write_attribute(aid.to_str(), list.map(rust_display_f32).join(" "))
}

///|
fn @xmlwriter.XmlWriter::write_filter_input(
  self : @xmlwriter.XmlWriter,
  id : AId,
  input : FilterInput,
) -> Unit {
  self.write_attribute(
    id.to_str(),
    match input {
      SourceGraphic => "SourceGraphic"
      SourceAlpha => "SourceAlpha"
      Reference(s) => s
    },
  )
}

///|
fn @xmlwriter.XmlWriter::write_filter_primitive_attrs(
  self : @xmlwriter.XmlWriter,
  parent_rect : NonZeroRect,
  fe : Primitive,
) -> Unit {
  if parent_rect.x() != fe.rect.x() {
    self.write_svg_attribute(AId::X, rust_display_f32(fe.rect.x()))
  }
  if parent_rect.y() != fe.rect.y() {
    self.write_svg_attribute(AId::Y, rust_display_f32(fe.rect.y()))
  }
  if parent_rect.width() != fe.rect.width() {
    self.write_svg_attribute(AId::Width, rust_display_f32(fe.rect.width()))
  }
  if parent_rect.height() != fe.rect.height() {
    self.write_svg_attribute(AId::Height, rust_display_f32(fe.rect.height()))
  }
  self.write_attribute(
    AId::ColorInterpolationFilters.to_str(),
    match fe.color_interpolation {
      SRGB => "sRGB"
      LinearRGB => "linearRGB"
    },
  )
}

///|
fn @xmlwriter.XmlWriter::write_filter_transfer_function(
  self : @xmlwriter.XmlWriter,
  eid : EId,
  fe : TransferFunction,
) -> Unit {
  self.start_svg_element(eid)
  match fe {
    Identity => self.write_svg_attribute(AId::Type, "identity")
    Table(values) => {
      self.write_svg_attribute(AId::Type, "table")
      self.write_numbers(AId::TableValues, values)
    }
    Discrete(values) => {
      self.write_svg_attribute(AId::Type, "discrete")
      self.write_numbers(AId::TableValues, values)
    }
    Linear(slope~, intercept~) => {
      self.write_svg_attribute(AId::Type, "linear")
      self.write_svg_attribute(AId::Slope, rust_display_f32(slope))
      self.write_svg_attribute(AId::Intercept, rust_display_f32(intercept))
    }
    Gamma(amplitude~, exponent~, offset~) => {
      self.write_svg_attribute(AId::Type, "gamma")
      self.write_svg_attribute(AId::Amplitude, rust_display_f32(amplitude))
      self.write_svg_attribute(AId::Exponent, rust_display_f32(exponent))
      self.write_svg_attribute(AId::Offset, rust_display_f32(offset))
    }
  }
  self.end_element()
}

///|
fn @xmlwriter.XmlWriter::write_image_data(
  self : @xmlwriter.XmlWriter,
  kind : ImageKind,
) -> Unit {
  let (mime, data) = match kind {
    JPEG(data) => ("jpeg", data)
    PNG(data) => ("png", data)
    GIF(data) => ("gif", data)
    WEBP(data) => ("webp", data)
    SVG(tree) => {
      let svg_string = tree.to_string(WriteOptions::default())
      ("svg+xml", @utf8.encode(svg_string))
    }
  }
  self.write_attribute(
    "xlink:href",
    "data:image/\{mime};base64, \{@base64.encode(data)}",
  )
}

///|
fn has_xlink(parent : Group) -> Bool {
  for node in parent.children {
    match node {
      Group(g) => {
        for filter in g.filters {
          if filter.primitives.iter().any(p => p.kind is Image(_)) {
            return true
          }
        }
        if g.mask is Some(mask) {
          if has_xlink(mask.root) {
            return true
          }
          if mask.mask is Some(sub_mask) {
            if has_xlink(sub_mask.root) {
              return true
            }
          }
        }
        if has_xlink(g) {
          return true
        }
      }
      Image(_) => return true
      Text(text) =>
        if text.chunks.iter().any(t => t.text_flow is Path(_)) {
          return true
        }
      _ => ()
    }
    let mut present = false
    node.subroots(root => present = present || has_xlink(root))
    if present {
      return true
    }
  }
  false
}

///|
fn write_base_grad(
  g : BaseGradient,
  opt : WriteOptions,
  xml : @xmlwriter.XmlWriter,
) -> Unit {
  xml.write_units(AId::GradientUnits, g.units, ObjectBoundingBox)
  xml.write_transform(AId::GradientTransform, g.transform, opt)
  match g.spread_method {
    Pad => ()
    Reflect => xml.write_svg_attribute(AId::SpreadMethod, "reflect")
    Repeat => xml.write_svg_attribute(AId::SpreadMethod, "repeat")
  }
  for s in g.stops {
    xml.start_svg_element(EId::Stop)
    xml.write_svg_attribute(AId::Offset, rust_display_f32(s.offset.get()))
    xml.write_color(AId::StopColor, s.color)
    if s.opacity != Opacity::one() {
      xml.write_svg_attribute(
        AId::StopOpacity,
        rust_display_f32(s.opacity.get()),
      )
    }
    xml.end_element()
  }
}

///|
fn write_path(
  path : Path,
  is_clip_path : Bool,
  path_transform : Transform,
  clip_path : String?,
  opt : WriteOptions,
  xml : @xmlwriter.XmlWriter,
) -> Unit {
  xml.start_svg_element(EId::Path)
  if !path.id.is_empty() {
    xml.write_id_attribute(path.id, opt)
  }
  write_fill(path.fill, is_clip_path, opt, xml)
  write_stroke(path.stroke, opt, xml)
  xml.write_visibility(path.visible)
  if path.paint_order == StrokeAndFill {
    xml.write_svg_attribute(AId::PaintOrder, "stroke")
  }
  match path.rendering_mode {
    OptimizeSpeed =>
      xml.write_svg_attribute(AId::ShapeRendering, "optimizeSpeed")
    CrispEdges => xml.write_svg_attribute(AId::ShapeRendering, "crispEdges")
    GeometricPrecision => ()
  }
  if clip_path is Some(id) {
    xml.write_func_iri(AId::ClipPath, id, opt)
  }
  xml.write_transform(AId::Transform, path_transform, opt)
  let buf = StringBuilder()
  let prec = opt.coordinates_precision
  let iter = path.data.segments()
  while iter.next() is Some(seg) {
    match seg {
      MoveTo(p) => {
        buf.write_string("M ")
        write_num(p.x, buf, prec)
        buf.write_char(' ')
        write_num(p.y, buf, prec)
        buf.write_char(' ')
      }
      LineTo(p) => {
        buf.write_string("L ")
        write_num(p.x, buf, prec)
        buf.write_char(' ')
        write_num(p.y, buf, prec)
        buf.write_char(' ')
      }
      QuadTo(p1, p) => {
        buf.write_string("Q ")
        write_num(p1.x, buf, prec)
        buf.write_char(' ')
        write_num(p1.y, buf, prec)
        buf.write_char(' ')
        write_num(p.x, buf, prec)
        buf.write_char(' ')
        write_num(p.y, buf, prec)
        buf.write_char(' ')
      }
      CubicTo(p1, p2, p) => {
        buf.write_string("C ")
        write_num(p1.x, buf, prec)
        buf.write_char(' ')
        write_num(p1.y, buf, prec)
        buf.write_char(' ')
        write_num(p2.x, buf, prec)
        buf.write_char(' ')
        write_num(p2.y, buf, prec)
        buf.write_char(' ')
        write_num(p.x, buf, prec)
        buf.write_char(' ')
        write_num(p.y, buf, prec)
        buf.write_char(' ')
      }
      Close => buf.write_string("Z ")
    }
  }
  // `buf.pop()`
  let d = buf.to_string()
  let d = if d.is_empty() {
    d
  } else {
    d.unsafe_substring(start=0, end=d.length() - 1)
  }
  xml.write_attribute("d", d)
  xml.end_element()
}

///|
fn write_fill(
  fill : Fill?,
  is_clip_path : Bool,
  opt : WriteOptions,
  xml : @xmlwriter.XmlWriter,
) -> Unit {
  if fill is Some(fill) {
    write_paint(AId::Fill, fill.paint, opt, xml)
    if fill.opacity != Opacity::one() {
      xml.write_svg_attribute(
        AId::FillOpacity,
        rust_display_f32(fill.opacity.get()),
      )
    }
    if fill.rule != FillRule::default() {
      let name = if is_clip_path { AId::ClipRule } else { AId::FillRule }
      xml.write_svg_attribute(name, "evenodd")
    }
  } else {
    xml.write_svg_attribute(AId::Fill, "none")
  }
}

///|
fn write_stroke(
  stroke : Stroke?,
  opt : WriteOptions,
  xml : @xmlwriter.XmlWriter,
) -> Unit {
  if stroke is Some(stroke) {
    write_paint(AId::Stroke, stroke.paint, opt, xml)
    if stroke.opacity != Opacity::one() {
      xml.write_svg_attribute(
        AId::StrokeOpacity,
        rust_display_f32(stroke.opacity.get()),
      )
    }
    if !approx_zero_ulps(stroke.dashoffset, 4) {
      xml.write_svg_attribute(
        AId::StrokeDashoffset,
        rust_display_f32(stroke.dashoffset),
      )
    }
    if stroke.miterlimit != StrokeMiterlimit::default() {
      xml.write_svg_attribute(
        AId::StrokeMiterlimit,
        rust_display_f32(stroke.miterlimit.get()),
      )
    }
    if stroke.width.get() != 1.0 {
      xml.write_svg_attribute(
        AId::StrokeWidth,
        rust_display_f32(stroke.width.get()),
      )
    }
    match stroke.linecap {
      Butt => ()
      Round => xml.write_svg_attribute(AId::StrokeLinecap, "round")
      Square => xml.write_svg_attribute(AId::StrokeLinecap, "square")
    }
    match stroke.linejoin {
      Miter => ()
      MiterClip => xml.write_svg_attribute(AId::StrokeLinejoin, "miter-clip")
      Round => xml.write_svg_attribute(AId::StrokeLinejoin, "round")
      Bevel => xml.write_svg_attribute(AId::StrokeLinejoin, "bevel")
    }
    if stroke.dasharray is Some(array) {
      xml.write_numbers(AId::StrokeDasharray, array)
    }
  } else {
    // Always set `stroke` to `none` to override the parent value.
    // In 99.9% of the cases it's redundant, but a group with `filter` with `StrokePaint`
    // will set `stroke`, which will interfere with children nodes.
    xml.write_svg_attribute(AId::Stroke, "none")
  }
}

///|
fn write_paint(
  aid : AId,
  paint : Paint,
  opt : WriteOptions,
  xml : @xmlwriter.XmlWriter,
) -> Unit {
  match paint {
    Color(c) => xml.write_color(aid, c)
    LinearGradient(lg) => xml.write_func_iri(aid, lg.id(), opt)
    RadialGradient(rg) => xml.write_func_iri(aid, rg.id(), opt)
    Pattern(patt) => xml.write_func_iri(aid, patt.id(), opt)
  }
}

///|
fn write_light_source(light : LightSource, xml : @xmlwriter.XmlWriter) -> Unit {
  match light {
    DistantLight(light) => {
      xml.start_svg_element(EId::FeDistantLight)
      xml.write_svg_attribute(AId::Azimuth, rust_display_f32(light.azimuth))
      xml.write_svg_attribute(AId::Elevation, rust_display_f32(light.elevation))
    }
    PointLight(light) => {
      xml.start_svg_element(EId::FePointLight)
      xml.write_svg_attribute(AId::X, rust_display_f32(light.x))
      xml.write_svg_attribute(AId::Y, rust_display_f32(light.y))
      xml.write_svg_attribute(AId::Z, rust_display_f32(light.z))
    }
    SpotLight(light) => {
      xml.start_svg_element(EId::FeSpotLight)
      xml.write_svg_attribute(AId::X, rust_display_f32(light.x))
      xml.write_svg_attribute(AId::Y, rust_display_f32(light.y))
      xml.write_svg_attribute(AId::Z, rust_display_f32(light.z))
      xml.write_svg_attribute(
        AId::PointsAtX,
        rust_display_f32(light.points_at_x),
      )
      xml.write_svg_attribute(
        AId::PointsAtY,
        rust_display_f32(light.points_at_y),
      )
      xml.write_svg_attribute(
        AId::PointsAtZ,
        rust_display_f32(light.points_at_z),
      )
      xml.write_svg_attribute(
        AId::SpecularExponent,
        rust_display_f32(light.specular_exponent.get()),
      )
      if light.limiting_cone_angle is Some(n) {
        xml.write_svg_attribute(AId::LimitingConeAngle, rust_display_f32(n))
      }
    }
  }
  xml.end_element()
}

///|
let pow_vec : ReadOnlyArray[Float] = [
  1.0, 10.0, 100.0, 1_000.0, 10_000.0, 100_000.0, 1_000_000.0, 10_000_000.0, 100_000_000.0,
  1_000_000_000.0, 10_000_000_000.0, 100_000_000_000.0, 1_000_000_000_000.0,
]

///|
fn write_num(num : Float, buf : StringBuilder, precision : Int) -> Unit {
  // If number is an integer, it's faster to write it as i32.
  if approx_zero_ulps(num - num.trunc(), 4) {
    buf.write_string(f32_as_i32(num).to_string())
    return
  }

  // Round numbers up to the specified precision to prevent writing
  // ugly numbers like 29.999999999999996.
  // It's not 100% correct, but differences are insignificant.
  //
  // Note that at least in Rust 1.64 the number formatting in debug and release modes
  // can be slightly different. So having a lower precision makes
  // our output and tests reproducible.
  let v = rust_round_f32(num * pow_vec[precision]) / pow_vec[precision]
  buf.write_string(rust_display_f32(v))
}

///|
/// Write all of the tspan attributes except for decorations.
fn write_span(
  is_clip_path : Bool,
  opt : WriteOptions,
  xml : @xmlwriter.XmlWriter,
  chunk : TextChunk,
  span : TextSpan,
) -> Unit {
  xml.start_svg_element(EId::Tspan)
  let font_family_to_str = (font_family : @svgtypes.FontFamily) => {
    match font_family {
      Monospace => "monospace"
      Serif => "serif"
      SansSerif => "sans-serif"
      Cursive => "cursive"
      Fantasy => "fantasy"
      Named(s) =>
        // Only quote if absolutely necessary
        try @svgtypes.parse_font_families(s) catch {
          _ => if opt.use_single_quote { "\"\{s}\"" } else { "'\{s}'" }
        } noraise {
          _ => s
        }
    }
  }
  if !span.font.families.is_empty() {
    let families = span.font.families.map(font_family_to_str).join(", ")
    xml.write_svg_attribute(AId::FontFamily, families)
  }
  match span.font.style {
    Normal => ()
    Italic => xml.write_svg_attribute(AId::FontStyle, "italic")
    Oblique => xml.write_svg_attribute(AId::FontStyle, "oblique")
  }
  if span.font.weight != 400 {
    xml.write_svg_attribute(AId::FontWeight, span.font.weight.to_string())
  }
  if span.font.stretch != FontStretch::Normal {
    let name = match span.font.stretch {
      Condensed => "condensed"
      ExtraCondensed => "extra-condensed"
      UltraCondensed => "ultra-condensed"
      SemiCondensed => "semi-condensed"
      Expanded => "expanded"
      SemiExpanded => "semi-expanded"
      ExtraExpanded => "extra-expanded"
      UltraExpanded => "ultra-expanded"
      Normal => abort("unreachable")
    }
    xml.write_svg_attribute(AId::FontStretch, name)
  }
  xml.write_svg_attribute(AId::FontSize, rust_display_f32(span.font_size.get()))
  xml.write_visibility(span.visible)
  if span.letter_spacing != 0.0 {
    xml.write_svg_attribute(
      AId::LetterSpacing,
      rust_display_f32(span.letter_spacing),
    )
  }
  if span.word_spacing != 0.0 {
    xml.write_svg_attribute(
      AId::WordSpacing,
      rust_display_f32(span.word_spacing),
    )
  }
  if span.text_length is Some(text_length) {
    xml.write_svg_attribute(AId::TextLength, rust_display_f32(text_length))
  }
  if span.length_adjust == SpacingAndGlyphs {
    xml.write_svg_attribute(AId::LengthAdjust, "spacingAndGlyphs")
  }
  if span.small_caps {
    xml.write_svg_attribute(AId::FontVariant, "small-caps")
  }
  if span.paint_order == StrokeAndFill {
    xml.write_svg_attribute(AId::PaintOrder, "stroke fill")
  }
  if !span.apply_kerning {
    xml.write_attribute("style", "font-kerning:none")
  }
  if span.dominant_baseline != DominantBaseline::Auto {
    let name = match span.dominant_baseline {
      UseScript => "use-script"
      NoChange => "no-change"
      ResetSize => "reset-size"
      TextBeforeEdge => "text-before-edge"
      Middle => "middle"
      Central => "central"
      TextAfterEdge => "text-after-edge"
      Ideographic => "ideographic"
      Alphabetic => "alphabetic"
      Hanging => "hanging"
      Mathematical => "mathematical"
      Auto => abort("unreachable")
    }
    xml.write_svg_attribute(AId::DominantBaseline, name)
  }
  if span.alignment_baseline != AlignmentBaseline::Auto {
    let name = match span.alignment_baseline {
      Baseline => "baseline"
      BeforeEdge => "before-edge"
      TextBeforeEdge => "text-before-edge"
      Middle => "middle"
      Central => "central"
      AfterEdge => "after-edge"
      TextAfterEdge => "text-after-edge"
      Ideographic => "ideographic"
      Alphabetic => "alphabetic"
      Hanging => "hanging"
      Mathematical => "mathematical"
      Auto => abort("unreachable")
    }
    xml.write_svg_attribute(AId::AlignmentBaseline, name)
  }
  write_fill(span.fill, is_clip_path, opt, xml)
  write_stroke(span.stroke, opt, xml)
  for baseline_shift in span.baseline_shift {
    xml.start_svg_element(EId::Tspan)
    match baseline_shift {
      Baseline => ()
      Number(num) =>
        xml.write_svg_attribute(AId::BaselineShift, rust_display_f32(num))
      Subscript => xml.write_svg_attribute(AId::BaselineShift, "sub")
      Superscript => xml.write_svg_attribute(AId::BaselineShift, "super")
    }
  }
  let cur_text = utf8_slice(chunk.text, span.start, span.end)
  xml.write_text(cur_text.replace_all(old="&", new="&amp;"))

  // End for each tspan we needed to create for baseline_shift
  for _ in span.baseline_shift {
    xml.end_element()
  }
  xml.end_element()
}

///|
/// Slices a string by UTF-8 byte offsets.
fn utf8_slice(s : String, start : Int, end : Int) -> String {
  let bytes = @utf8.encode(s)
  @utf8.decode_lossy(bytes[start:end])
}
