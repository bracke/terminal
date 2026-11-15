with Ada.Text_IO;

package Unicode_Generator_Support is
   Max_Code_Point : constant Natural := 16#10FFFF#;

   type Flag_Array is array (Natural range <>) of Boolean;
   type Flag_Array_Access is access Flag_Array;

   function Hex_Value (Text : String) return Natural;
   function Hex_Image (Value : Natural) return String;

   procedure Mark
     (Flags : Flag_Array_Access;
      First : Natural;
      Last  : Natural);

   procedure Parse_Property_Line
     (Raw      : String;
      First_CP : out Natural;
      Last_CP  : out Natural;
      Property : out String;
      Valid    : out Boolean);

   procedure Parse_Variation_Line
     (Raw         : String;
      Base_CP     : out Natural;
      Selector_CP : out Natural;
      Valid       : out Boolean);

   procedure Write_Intervals
     (Output : Ada.Text_IO.File_Type;
      Name   : String;
      Flags  : Flag_Array_Access);

   function Same_Text_Files
     (Left_Path  : String;
      Right_Path : String) return Boolean;
end Unicode_Generator_Support;
