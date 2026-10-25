separate (Terminal.App.Renderer)
procedure Ensure_Frame_Capacity
  (R               : in out Renderer;
   Rectangle_Count : Positive;
   Glyph_Count     : Positive;
   Colour_Count    : Positive;
   Image_Count     : Positive;
   Text_Run_Count  : Positive;
   Success         : out Boolean)
is
begin
   if R.Rectangles = null or else R.Rectangles'Length < Rectangle_Count then
      declare
         Replacement : RM.Rectangle_Array_Access :=
           new RM.Rectangle_Array
             (1 .. Grown_Capacity
               ((if R.Rectangles = null then 0 else R.Rectangles'Length),
                Rectangle_Count));
      begin
         Free_Rectangles (R.Rectangles);
         R.Rectangles := Replacement;
      end;
   end if;
   if R.Glyphs = null or else R.Glyphs'Length < Glyph_Count then
      declare
         Replacement : RM.Glyph_Array_Access :=
           new RM.Glyph_Array
             (1 .. Grown_Capacity
               ((if R.Glyphs = null then 0 else R.Glyphs'Length), Glyph_Count));
      begin
         Free_Glyphs (R.Glyphs);
         R.Glyphs := Replacement;
      end;
   end if;
   if R.Colour_Glyphs = null
     or else R.Colour_Glyphs'Length < Colour_Count
   then
      declare
         Replacement : RM.Colour_Glyph_Array_Access :=
           new RM.Colour_Glyph_Array
             (1 .. Grown_Capacity
               ((if R.Colour_Glyphs = null
                 then 0 else R.Colour_Glyphs'Length), Colour_Count));
      begin
         Free_Colour_Glyphs (R.Colour_Glyphs);
         R.Colour_Glyphs := Replacement;
      end;
   end if;
   FIS.Ensure_Capacity (R.Frame_Images, Image_Count, Success);
   if not Success then
      return;
   end if;
   if R.Text_Runs = null or else R.Text_Runs'Length < Text_Run_Count then
      declare
         Replacement : RM.Text_Run_Array_Access :=
           new RM.Text_Run_Array
             (1 .. Grown_Capacity
               ((if R.Text_Runs = null then 0 else R.Text_Runs'Length),
                Text_Run_Count));
      begin
         Free_Text_Runs (R.Text_Runs);
         R.Text_Runs := Replacement;
      end;
   end if;
   if R.Shaped_Run_Map = null
     or else R.Shaped_Run_Map'Length < Text_Run_Count
   then
      declare
         Replacement : Shaped_Run_Map_Array_Access :=
           new Shaped_Run_Map_Array
             (1 .. Grown_Capacity
               ((if R.Shaped_Run_Map = null
                 then 0 else R.Shaped_Run_Map'Length), Text_Run_Count));
      begin
         Free_Shaped_Run_Map (R.Shaped_Run_Map);
         R.Shaped_Run_Map := Replacement;
      end;
   end if;
   Success := True;
exception
   when Storage_Error =>
      Success := False;
end Ensure_Frame_Capacity;
