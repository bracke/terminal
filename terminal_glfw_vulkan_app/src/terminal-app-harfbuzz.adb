with Ada.Unchecked_Conversion;

with Interfaces.C;
with Interfaces.C.Strings;

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

   function Direction_Tag
     (Direction : RM.Text_Run_Direction) return String
   is
   begin
      case Direction is
         when RM.Direction_Right_To_Left =>
            return "rtl";
         when RM.Direction_Left_To_Right =>
            return "ltr";
         when RM.Direction_Neutral =>
            return "ltr";
      end case;
   end Direction_Tag;

   function Script_Tag (Script : RM.Text_Run_Script) return String is
   begin
      case Script is
         when RM.Script_Latin =>
            return "latn";
         when RM.Script_Hebrew =>
            return "hebr";
         when RM.Script_Arabic =>
            return "arab";
         when RM.Script_Devanagari =>
            return "deva";
         when RM.Script_Bengali =>
            return "beng";
         when RM.Script_Gurmukhi =>
            return "guru";
         when RM.Script_Gujarati =>
            return "gujr";
         when RM.Script_Oriya =>
            return "orya";
         when RM.Script_Tamil =>
            return "taml";
         when RM.Script_Telugu =>
            return "telu";
         when RM.Script_Kannada =>
            return "knda";
         when RM.Script_Malayalam =>
            return "mlym";
         when RM.Script_Sinhala =>
            return "sinh";
         when RM.Script_Thai =>
            return "thai";
         when RM.Script_Lao =>
            return "laoo";
         when RM.Script_Myanmar =>
            return "mymr";
         when RM.Script_Khmer =>
            return "khmr";
         when RM.Script_Javanese =>
            return "java";
         when RM.Script_Cham =>
            return "cham";
         when RM.Script_CJK =>
            return "hani";
         when RM.Script_Emoji =>
            return "zyyy";
         when RM.Script_Common | RM.Script_Unknown =>
            return "zyyy";
      end case;
   end Script_Tag;

   function Language_Tag (Script : RM.Text_Run_Script) return String is
   begin
      case Script is
         when RM.Script_Latin =>
            return "en";
         when RM.Script_Hebrew =>
            return "he";
         when RM.Script_Arabic =>
            return "ar";
         when RM.Script_Devanagari =>
            return "hi";
         when RM.Script_Bengali =>
            return "bn";
         when RM.Script_Gurmukhi =>
            return "pa";
         when RM.Script_Gujarati =>
            return "gu";
         when RM.Script_Oriya =>
            return "or";
         when RM.Script_Tamil =>
            return "ta";
         when RM.Script_Telugu =>
            return "te";
         when RM.Script_Kannada =>
            return "kn";
         when RM.Script_Malayalam =>
            return "ml";
         when RM.Script_Sinhala =>
            return "si";
         when RM.Script_Thai =>
            return "th";
         when RM.Script_Lao =>
            return "lo";
         when RM.Script_Myanmar =>
            return "my";
         when RM.Script_Khmer =>
            return "km";
         when RM.Script_Javanese =>
            return "jv";
         when RM.Script_Cham =>
            return "cjm";
         when RM.Script_CJK =>
            return "zh";
         when RM.Script_Emoji | RM.Script_Common | RM.Script_Unknown =>
            return "und";
      end case;
   end Language_Tag;

   procedure Set_Buffer_Properties
     (Buffer : System.Address;
      Run    : RM.Text_Run_Command)
   is
      Direction_Tag_Text : constant String := Direction_Tag (Run.Direction);
      Script_Tag_Text    : constant String := Script_Tag (Run.Script);
      Language_Tag_Text  : constant String := Language_Tag (Run.Script);
      Direction_Text : CStr.chars_ptr :=
        CStr.New_String (Direction_Tag_Text);
      Script_Text    : CStr.chars_ptr :=
        CStr.New_String (Script_Tag_Text);
      Language_Text  : CStr.chars_ptr := CStr.New_String (Language_Tag_Text);
   begin
      HB_Buffer_Set_Direction
        (Buffer,
         HB_Direction_From_String
           (Direction_Text, C.int (Direction_Tag_Text'Length)));
      HB_Buffer_Set_Script
        (Buffer,
         HB_Script_From_String
           (Script_Text, C.int (Script_Tag_Text'Length)));
      HB_Buffer_Set_Language
        (Buffer,
         HB_Language_From_String
           (Language_Text, C.int (Language_Tag_Text'Length)));
      CStr.Free (Direction_Text);
      CStr.Free (Script_Text);
      CStr.Free (Language_Text);
   exception
      when others =>
         CStr.Free (Direction_Text);
         CStr.Free (Script_Text);
         CStr.Free (Language_Text);
         raise;
   end Set_Buffer_Properties;

   procedure Load
     (Face        : in out Font_Face;
      Path        : String;
      Pixel_Size  : Positive;
      Status      : out Load_Status)
   is
      File_Name : CStr.chars_ptr;
   begin
      Reset (Face);

      if Path = "" then
         Status := Invalid_Path;
         return;
      end if;

      File_Name := CStr.New_String (Path);
      Face.Blob := HB_Blob_Create_From_File_Or_Fail (File_Name);
      CStr.Free (File_Name);

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
      Face.Pixel_Size := Pixel_Size;
      Status := Loaded;
   exception
      when others =>
         Reset (Face);
         Status := Load_Failed;
   end Load;

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
      HB_Shape (Face.Font, Buffer, System.Null_Address, 0);

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
