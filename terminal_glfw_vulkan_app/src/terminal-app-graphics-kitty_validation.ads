private package Terminal.App.Graphics.Kitty_Validation is
   procedure Parse_Header
     (Params   : String;
      Has_Data : Boolean;
      Result   : out Graphics_Header);

private
   type Field_Bounds is record
      Present : Boolean := False;
      First   : Natural := 0;
      Last    : Natural := 0;
   end record;
   type Control_Fields is array (Character) of Field_Bounds;
end Terminal.App.Graphics.Kitty_Validation;
