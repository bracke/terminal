private package Terminal.App.ITerm2_Controls is
   type Field_Kind is
     (Inline_Field,
      Name_Field,
      Width_Field,
      Height_Field,
      Preserve_Aspect_Field,
      Do_Not_Move_Field,
      Size_Field);

   type Parsed_Controls is private;

   procedure Parse (Text : String; Result : out Parsed_Controls);
   function Recognized (Result : Parsed_Controls) return Boolean;
   function Valid (Result : Parsed_Controls) return Boolean;
   function Has_Data (Result : Parsed_Controls) return Boolean;
   function Data_First (Result : Parsed_Controls) return Natural;
   function Value
     (Text   : String;
      Result : Parsed_Controls;
      Field  : Field_Kind) return String;

private
   type Field_Bounds is record
      Present : Boolean := False;
      First   : Natural := 0;
      Last    : Natural := 0;
   end record;
   type Field_Array is array (Field_Kind) of Field_Bounds;
   type Parsed_Controls is record
      Is_Recognized : Boolean := False;
      Is_Valid      : Boolean := True;
      Contains_Data : Boolean := False;
      Payload_First : Natural := 0;
      Fields        : Field_Array := (others => <>);
   end record;
end Terminal.App.ITerm2_Controls;
