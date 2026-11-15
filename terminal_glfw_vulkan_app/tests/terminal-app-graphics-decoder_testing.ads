with Terminal.App.Graphics.Decoding;

--  Test-only name for the low-level decoder surface.  Keeping this child in
--  the test source directory prevents a testing facade from being installed
--  with the production application packages.
package Terminal.App.Graphics.Decoder_Testing
  renames Terminal.App.Graphics.Decoding;
