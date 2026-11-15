with AUnit.Assertions;
with Terminal.Common.Sixel;

procedure Common_Sixel_Smoke is
   use AUnit.Assertions;
   First : constant Terminal.Common.Sixel.Analysis :=
     Terminal.Common.Sixel.Analyze ("q?--");
   Aspect : constant Terminal.Common.Sixel.Analysis :=
     Terminal.Common.Sixel.Analyze ("1;1q""2;1;8;6~");
   Private_Header : constant Terminal.Common.Sixel.Analysis :=
     Terminal.Common.Sixel.Analyze ("?1;0q~");
   Empty_Raster : constant Terminal.Common.Sixel.Analysis :=
     Terminal.Common.Sixel.Analyze ("q""1;1;8;0");
begin
   Assert
     (First.Width = 1
      and then First.Logical_Height = 12
      and then First.Height = 12,
      "raster newlines contribute to the shared sixel extent");
   Assert
     (Aspect.Width = 8
      and then Aspect.Logical_Height = 6
      and then Aspect.Height = 12
      and then Aspect.Vertical_Aspect = 2
      and then Aspect.Transparent,
      "sixel parameters and raster attributes share one analysis");
   Assert
     (Private_Header.Width = 1 and then Private_Header.Logical_Height = 6,
      "private sixel introducers cannot stall header analysis");
   Assert
     (Empty_Raster.Width = 0 and then Empty_Raster.Height = 0,
      "a sixel raster with an empty dimension has an empty extent");
end Common_Sixel_Smoke;
