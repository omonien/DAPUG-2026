{ -----------------------------------------------------------------------------
  /// <summary>
  ///   Canonical describe prompt sent to Gemini Flash for every successful
  ///   upscale job, instructing the model to return a JSON title + caption.
  /// </summary>
  /// <remarks>
  ///   The text is intentionally fixed: the demo's whole behavior is shaped
  ///   by these instructions. Changing this string changes the output of
  ///   every future description - guarded by a byte-exact unit test in
  ///   IUS.Tests.DescribePrompt.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit IUS.DescribePrompt;

interface

uses
  System.SysUtils;

const
  /// <summary>Verbatim text sent as the prompt part of every describe call.</summary>
  cDescribePrompt =
    'You are looking at a single photographic image. Produce a JSON ' +
    'object with two fields:' + sLineBreak +
    '  title:   A 2-5 word noun phrase naming the dominant subject ' +
    'or scene.' + sLineBreak +
    '  caption: One or two sentences describing what is visible - ' +
    'subject, setting, mood, notable details. Plain prose, no lists, ' +
    'no markdown. Do not speculate beyond what is depicted.';

implementation

end.
