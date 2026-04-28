{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Canonical remaster prompt sent to Nano Banana Pro on every upscale.
  /// </summary>
  /// <remarks>
  ///   The text is intentionally fixed: the demo's whole behavior is shaped
  ///   by these instructions. Changing this string changes the output of
  ///   every future upscale - guarded by a byte-exact unit test in
  ///   IUS.Tests.Prompt.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit IUS.Prompt;

interface

uses
  System.SysUtils;

const
  /// <summary>Verbatim text sent as the prompt part of every generateContent call.</summary>
  cRemasterPrompt =
    'Take the provided image and remaster it to pristine ultra-high-definition cinematic quality. ' +
    'Every aspect of the original must remain completely intact - the person''s facial identity, ' +
    'expression, body posture, clothing, accessories, environment, framing and overall composition ' +
    'stay exactly as they are. No elements are changed, added or removed.' + sLineBreak +
    'The upgrade is purely technical.' + sLineBreak +
    'Reconstruct skin texture with natural visible pores and subtle real-world detail. ' +
    'Define individual hair strands with precision.' + sLineBreak +
    'Render the eyes sharp, clear and fully alive.' + sLineBreak +
    'Clean and resolve every edge throughout the entire image.' + sLineBreak +
    'Enhance the dynamic range, contrast and three-dimensional depth using balanced studio-grade ' +
    'cinematic lighting that makes every surface feel physically present and real.';

implementation

end.
