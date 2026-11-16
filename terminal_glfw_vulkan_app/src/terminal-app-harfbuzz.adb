with Ada.Unchecked_Conversion;
with Ada.Strings;
with Ada.Strings.Fixed;

with Interfaces.C;
with Interfaces.C.Strings;
with Terminal.Common.C_Strings;
with Terminal.App.Text_Shaping_Tags;

package body Terminal.App.HarfBuzz is
   package C renames Interfaces.C;
   package CStr renames Interfaces.C.Strings;
   package RM renames Terminal.App.Render_Model;

   use type C.int;
   use type C.unsigned;
   use type System.Address;

   type UInt32_Array is array (Natural range <>) of aliased C.unsigned;
   pragma Convention (C, UInt32_Array);

   type Glyph_Info is record
      Codepoint : C.unsigned;
      Mask      : C.unsigned;
      Cluster   : C.unsigned;
      Var_1     : C.unsigned;
      Var_2     : C.unsigned;
   end record;
   pragma Convention (C, Glyph_Info);

   type Glyph_Position is record
      X_Advance : C.int;
      Y_Advance : C.int;
      X_Offset  : C.int;
      Y_Offset  : C.int;
      Reserved  : C.unsigned;
   end record;
   pragma Convention (C, Glyph_Position);

   type HB_Feature is record
      Tag : C.unsigned;
      Value : C.unsigned;
      Start : C.unsigned;
      Stop : C.unsigned;
   end record;
   pragma Convention (C, HB_Feature);
   type HB_Feature_Array is array (Natural range 0 .. 31) of aliased HB_Feature;
   pragma Convention (C, HB_Feature_Array);

   type HB_Variation is record
      Tag : C.unsigned;
      Value : C.C_float;
   end record;
   pragma Convention (C, HB_Variation);
   type HB_Variation_Array is
     array (Natural range 0 .. 31) of aliased HB_Variation;
   pragma Convention (C, HB_Variation_Array);

   type Glyph_Info_Array is
     array (Natural range 0 .. RM.Max_Shaped_Glyphs_Per_Run - 1) of
       aliased Glyph_Info;
   pragma Convention (C, Glyph_Info_Array);
   type Glyph_Info_Array_Access is access all Glyph_Info_Array;

   type Glyph_Position_Array is
     array (Natural range 0 .. RM.Max_Shaped_Glyphs_Per_Run - 1) of
       aliased Glyph_Position;
   pragma Convention (C, Glyph_Position_Array);
   type Glyph_Position_Array_Access is access all Glyph_Position_Array;

   function To_Info_Array is new Ada.Unchecked_Conversion
     (System.Address, Glyph_Info_Array_Access);
   function To_Position_Array is new Ada.Unchecked_Conversion
     (System.Address, Glyph_Position_Array_Access);

   function HB_Blob_Create_From_File_Or_Fail
     (File_Name : CStr.chars_ptr) return System.Address
   with Import, Convention => C,
        External_Name => "hb_blob_create_from_file_or_fail";

   procedure HB_Blob_Destroy (Blob : System.Address)
   with Import, Convention => C, External_Name => "hb_blob_destroy";

   function HB_Face_Create
     (Blob : System.Address;
      Index : C.unsigned) return System.Address
   with Import, Convention => C, External_Name => "hb_face_create";

   procedure HB_Face_Destroy (Face : System.Address)
   with Import, Convention => C, External_Name => "hb_face_destroy";

   function HB_Font_Create (Face : System.Address) return System.Address
   with Import, Convention => C, External_Name => "hb_font_create";

   procedure HB_Font_Destroy (Font : System.Address)
   with Import, Convention => C, External_Name => "hb_font_destroy";

   procedure HB_OT_Font_Set_Funcs (Font : System.Address)
   with Import, Convention => C, External_Name => "hb_ot_font_set_funcs";

   procedure HB_Font_Set_Scale
     (Font    : System.Address;
      X_Scale : C.int;
      Y_Scale : C.int)
   with Import, Convention => C, External_Name => "hb_font_set_scale";

   function HB_Feature_From_String
     (Text : CStr.chars_ptr;
      Length : C.int;
      Feature : access HB_Feature) return C.int
   with Import, Convention => C, External_Name => "hb_feature_from_string";

   function HB_Variation_From_String
     (Text : CStr.chars_ptr;
      Length : C.int;
      Variation : access HB_Variation) return C.int
   with Import, Convention => C, External_Name => "hb_variation_from_string";

   procedure HB_Font_Set_Variations
     (Font : System.Address;
      Variations : access HB_Variation;
      Count : C.unsigned)
   with Import, Convention => C, External_Name => "hb_font_set_variations";

   function HB_Buffer_Create return System.Address
   with Import, Convention => C, External_Name => "hb_buffer_create";

   procedure HB_Buffer_Destroy (Buffer : System.Address)
   with Import, Convention => C, External_Name => "hb_buffer_destroy";

   procedure HB_Buffer_Add_UTF32
     (Buffer      : System.Address;
      Text        : access C.unsigned;
      Text_Length : C.int;
      Item_Offset : C.unsigned;
      Item_Length : C.int)
   with Import, Convention => C, External_Name => "hb_buffer_add_utf32";

   function HB_Direction_From_String
     (Text : CStr.chars_ptr;
      Len  : C.int) return C.unsigned
   with Import, Convention => C, External_Name => "hb_direction_from_string";

   procedure HB_Buffer_Set_Direction
     (Buffer    : System.Address;
      Direction : C.unsigned)
   with Import, Convention => C, External_Name => "hb_buffer_set_direction";

   function HB_Script_From_String
     (Text : CStr.chars_ptr;
      Len  : C.int) return C.unsigned
   with Import, Convention => C, External_Name => "hb_script_from_string";

   procedure HB_Buffer_Set_Script
     (Buffer : System.Address;
      Script : C.unsigned)
   with Import, Convention => C, External_Name => "hb_buffer_set_script";

   function HB_Language_From_String
     (Text : CStr.chars_ptr;
      Len  : C.int) return System.Address
   with Import, Convention => C, External_Name => "hb_language_from_string";

   procedure HB_Buffer_Set_Language
     (Buffer   : System.Address;
      Language : System.Address)
   with Import, Convention => C, External_Name => "hb_buffer_set_language";

   procedure HB_Shape
     (Font         : System.Address;
      Buffer       : System.Address;
      Features     : System.Address;
      Num_Features : C.unsigned)
   with Import, Convention => C, External_Name => "hb_shape";

   function HB_Buffer_Get_Length (Buffer : System.Address) return C.unsigned
   with Import, Convention => C, External_Name => "hb_buffer_get_length";

   function HB_Buffer_Get_Glyph_Infos
     (Buffer : System.Address;
      Length : access C.unsigned) return System.Address
   with Import, Convention => C, External_Name => "hb_buffer_get_glyph_infos";

   function HB_Buffer_Get_Glyph_Positions
     (Buffer : System.Address;
      Length : access C.unsigned) return System.Address
   with Import, Convention => C,
        External_Name => "hb_buffer_get_glyph_positions";

   function Scale (Value : Float) return C.int is
     (C.int (Value * 64.0));

   function To_Float_Pixels (Value : C.int) return Float is
     (Float (Value) / 64.0);

   procedure Set_Buffer_Properties
     (Buffer : System.Address;
      Run    : RM.Text_Run_Command)
   is
      Direction_Tag_Text : constant String :=
        Terminal.App.Text_Shaping_Tags.Direction_Tag (Run.Direction);
      Script_Tag_Text : constant String :=
        Terminal.App.Text_Shaping_Tags.Script_Tag (Run.Script);
      Language_Tag_Text : constant String :=
        Terminal.App.Text_Shaping_Tags.Language_Tag;
      Direction_Text : Terminal.Common.C_Strings.Owner;
      Script_Text    : Terminal.Common.C_Strings.Owner;
      Language_Text  : Terminal.Common.C_Strings.Owner;
   begin
      Terminal.Common.C_Strings.Set (Direction_Text, Direction_Tag_Text);
      Terminal.Common.C_Strings.Set (Script_Text, Script_Tag_Text);
      Terminal.Common.C_Strings.Set (Language_Text, Language_Tag_Text);
      HB_Buffer_Set_Direction
        (Buffer,
         HB_Direction_From_String
           (Terminal.Common.C_Strings.Unsafe_Pointer (Direction_Text),
            C.int (Direction_Tag_Text'Length)));
      HB_Buffer_Set_Script
        (Buffer,
         HB_Script_From_String
           (Terminal.Common.C_Strings.Unsafe_Pointer (Script_Text),
            C.int (Script_Tag_Text'Length)));
      HB_Buffer_Set_Language
        (Buffer,
         HB_Language_From_String
           (Terminal.Common.C_Strings.Unsafe_Pointer (Language_Text),
            C.int (Language_Tag_Text'Length)));
   end Set_Buffer_Properties;

   procedure Load
     (Face   : in out Font_Face;
      Path   : String;
      Status : out Load_Status)
   is
      File_Name : Terminal.Common.C_Strings.Owner;
   begin
      Reset (Face);

      if Path = "" then
         Status := Invalid_Path;
         return;
      end if;

      Terminal.Common.C_Strings.Set (File_Name, Path);
      Face.Blob := HB_Blob_Create_From_File_Or_Fail
        (Terminal.Common.C_Strings.Unsafe_Pointer (File_Name));

      if Face.Blob = System.Null_Address then
         Status := Load_Failed;
         return;
      end if;

      Face.Face := HB_Face_Create (Face.Blob, 0);
      if Face.Face = System.Null_Address then
         Reset (Face);
         Status := Load_Failed;
         return;
      end if;

      Face.Font := HB_Font_Create (Face.Face);
      if Face.Font = System.Null_Address then
         Reset (Face);
         Status := Load_Failed;
         return;
      end if;

      HB_OT_Font_Set_Funcs (Face.Font);
      Status := Loaded;
   exception
      when others =>
         Reset (Face);
         Status := Load_Failed;
   end Load;

   procedure Configure
     (Face       : in out Font_Face;
      Features   : String;
      Variations : String;
      Accepted   : out Boolean)
   is
      Variation_Items : HB_Variation_Array := (others => (0, 0.0));
      Variation_Count : Natural := 0;

      procedure Parse_Variations is
         First : Natural := Variations'First;
         Comma : Natural;
      begin
         while First <= Variations'Last loop
            Comma := Ada.Strings.Fixed.Index (Variations, ",", From => First);
            if Comma = 0 then Comma := Variations'Last + 1; end if;
            declare
               Token : constant String := Ada.Strings.Fixed.Trim
                 (Variations (First .. Comma - 1), Ada.Strings.Both);
               Owner : Terminal.Common.C_Strings.Owner;
            begin
               if Token = "" or else Variation_Count = Variation_Items'Length then
                  Accepted := False;
                  return;
               end if;
               Terminal.Common.C_Strings.Set (Owner, Token);
               if HB_Variation_From_String
                 (Terminal.Common.C_Strings.Unsafe_Pointer (Owner),
                  C.int (Token'Length),
                  Variation_Items (Variation_Count)'Access) = 0
               then
                  Accepted := False;
                  return;
               end if;
               Variation_Count := Variation_Count + 1;
            end;
            First := Comma + 1;
         end loop;
      end Parse_Variations;

      procedure Validate_Features is
         First : Natural := Features'First;
         Comma : Natural;
         Dummy : aliased HB_Feature;
      begin
         while First <= Features'Last loop
            Comma := Ada.Strings.Fixed.Index (Features, ",", From => First);
            if Comma = 0 then Comma := Features'Last + 1; end if;
            declare
               Token : constant String := Ada.Strings.Fixed.Trim
                 (Features (First .. Comma - 1), Ada.Strings.Both);
               Owner : Terminal.Common.C_Strings.Owner;
            begin
               if Token = "" then Accepted := False; return; end if;
               Terminal.Common.C_Strings.Set (Owner, Token);
               if HB_Feature_From_String
                 (Terminal.Common.C_Strings.Unsafe_Pointer (Owner),
                  C.int (Token'Length), Dummy'Access) = 0
               then
                  Accepted := False;
                  return;
               end if;
            end;
            First := Comma + 1;
         end loop;
      end Validate_Features;
   begin
      Accepted := Features'Length <= Max_Configuration_Length
        and then Variations'Length <= Max_Configuration_Length
        and then Face.Font /= System.Null_Address;
      if not Accepted then return; end if;
      if Features /= "" then Validate_Features; end if;
      if not Accepted then return; end if;
      if Variations /= "" then Parse_Variations; end if;
      if not Accepted then return; end if;
      Face.Feature_Length := Features'Length;
      Face.Feature_Text := (others => ASCII.NUL);
      if Features /= "" then
         Face.Feature_Text (1 .. Features'Length) := Features;
      end if;
      if Variation_Count > 0 then
         HB_Font_Set_Variations
           (Face.Font, Variation_Items (0)'Access,
            C.unsigned (Variation_Count));
      end if;
   end Configure;

   procedure Reset (Face : in out Font_Face) is
   begin
      if Face.Font /= System.Null_Address then
         HB_Font_Destroy (Face.Font);
      end if;
      if Face.Face /= System.Null_Address then
         HB_Face_Destroy (Face.Face);
      end if;
      if Face.Blob /= System.Null_Address then
         HB_Blob_Destroy (Face.Blob);
      end if;

      Face.Font := System.Null_Address;
      Face.Face := System.Null_Address;
      Face.Blob := System.Null_Address;
   end Reset;

   overriding procedure Finalize (Face : in out Font_Face) is
   begin
      Reset (Face);
   end Finalize;

   function Is_Loaded (Face : Font_Face) return Boolean is
     (Face.Font /= System.Null_Address);

   procedure Shape
     (Face   : Font_Face;
      Font_Index : Natural;
      Run    : in out RM.Text_Run_Command;
      Status : out Shape_Status)
   is
      Input            : aliased UInt32_Array
        (0 .. RM.Max_Text_Run_Codepoints - 1);
      Buffer           : System.Address := System.Null_Address;
      HB_Length        : aliased C.unsigned := 0;
      Info_Address     : System.Address;
      Position_Address : System.Address;
      Infos           : Glyph_Info_Array_Access;
      Positions       : Glyph_Position_Array_Access;
      Glyph_Count     : Natural;
      Feature_Items   : HB_Feature_Array :=
        (others => (Tag => 0, Value => 0, Start => 0, Stop => 0));
      Feature_Count   : Natural := 0;
   begin
      Run.Shaped_Glyphs := (others => <>);
      Run.Shaped_Glyph_Count := 0;

      if not Is_Loaded (Face) then
         Status := Not_Loaded;
         return;
      elsif Run.Codepoint_Count = 0 then
         Status := Invalid_Run;
         return;
      end if;

      for I in Input'Range loop
         Input (I) := C.unsigned (Run.Codepoints (I + 1));
      end loop;

      Buffer := HB_Buffer_Create;
      if Buffer = System.Null_Address then
         Status := Shape_Failed;
         return;
      end if;

      HB_Font_Set_Scale
        (Face.Font,
         Scale (Run.Cell_Width),
         Scale (Run.Cell_Height));
      Set_Buffer_Properties (Buffer, Run);
      HB_Buffer_Add_UTF32
        (Buffer,
         Input (Input'First)'Access,
         C.int (Run.Codepoint_Count),
         0,
         C.int (Run.Codepoint_Count));
      if Face.Feature_Length > 0 then
         declare
            Features : constant String :=
              Face.Feature_Text (1 .. Face.Feature_Length);
            First : Natural := Features'First;
            Comma : Natural;
         begin
            while First <= Features'Last loop
               Comma := Ada.Strings.Fixed.Index (Features, ",", From => First);
               if Comma = 0 then Comma := Features'Last + 1; end if;
               declare
                  Token : constant String := Ada.Strings.Fixed.Trim
                    (Features (First .. Comma - 1), Ada.Strings.Both);
                  Owner : Terminal.Common.C_Strings.Owner;
               begin
                  Terminal.Common.C_Strings.Set (Owner, Token);
                  if Feature_Count < Feature_Items'Length
                    and then HB_Feature_From_String
                      (Terminal.Common.C_Strings.Unsafe_Pointer (Owner),
                       C.int (Token'Length),
                       Feature_Items (Feature_Count)'Access) /= 0
                  then
                     Feature_Count := Feature_Count + 1;
                  end if;
               end;
               First := Comma + 1;
            end loop;
         end;
      end if;
      HB_Shape
        (Face.Font, Buffer,
         (if Feature_Count = 0 then System.Null_Address
          else Feature_Items (0)'Address),
         C.unsigned (Feature_Count));

      Glyph_Count := Natural (HB_Buffer_Get_Length (Buffer));
      if Glyph_Count = 0 then
         HB_Buffer_Destroy (Buffer);
         Status := Shape_Failed;
         return;
      elsif Glyph_Count > RM.Max_Shaped_Glyphs_Per_Run then
         HB_Buffer_Destroy (Buffer);
         Status := Buffer_Overflow;
         return;
      end if;

      Info_Address := HB_Buffer_Get_Glyph_Infos (Buffer, HB_Length'Access);
      if Info_Address = System.Null_Address
        or else Natural (HB_Length) < Glyph_Count
      then
         HB_Buffer_Destroy (Buffer);
         Status := Shape_Failed;
         return;
      end if;

      Position_Address :=
        HB_Buffer_Get_Glyph_Positions (Buffer, HB_Length'Access);
      if Position_Address = System.Null_Address
        or else Natural (HB_Length) < Glyph_Count
      then
         HB_Buffer_Destroy (Buffer);
         Status := Shape_Failed;
         return;
      end if;

      Infos := To_Info_Array (Info_Address);
      Positions := To_Position_Array (Position_Address);

      for I in 0 .. Glyph_Count - 1 loop
         declare
            Source : constant Natural := Natural (Infos (I).Cluster) + 1;
         begin
            Run.Shaped_Glyphs (I + 1) :=
              (Glyph_ID     => Natural (Infos (I).Codepoint),
               Font_Index   => Font_Index,
               Codepoint    =>
                 (if Source in 1 .. Natural (Run.Codepoint_Count)
                  then Run.Codepoints (Source)
                  else 0),
               Source_Index =>
                 (if Source in 1 .. Natural (Run.Codepoint_Count)
                  then RM.Text_Run_Codepoint_Count (Source)
                  else 0),
               X_Offset     => To_Float_Pixels (Positions (I).X_Offset),
               Y_Offset     => To_Float_Pixels (Positions (I).Y_Offset),
               X_Advance    => To_Float_Pixels (Positions (I).X_Advance),
               Y_Advance    => To_Float_Pixels (Positions (I).Y_Advance));
         end;
      end loop;

      Run.Shaped_Glyph_Count := RM.Shaped_Glyph_Total (Glyph_Count);
      HB_Buffer_Destroy (Buffer);
      Status := Shaped;
   exception
      when others =>
         if Buffer /= System.Null_Address then
            HB_Buffer_Destroy (Buffer);
         end if;
         Status := Shape_Failed;
   end Shape;
end Terminal.App.HarfBuzz;
