with System;

--  Renderer-neutral terminal draw commands.
--
--  The terminal renderer builds these commands from Terminal.Core snapshots.
--  A Vulkan adapter can consume them without parsing terminal data or owning
--  terminal state.
package Terminal.App.Render_Model is
   type Pixel_Color is record
      R : Float := 0.0;
      G : Float := 0.0;
      B : Float := 0.0;
      A : Float := 1.0;
   end record;

   type Rectangle_Command is record
      X      : Float := 0.0;
      Y      : Float := 0.0;
      Width  : Float := 0.0;
      Height : Float := 0.0;
      Color  : Pixel_Color;
   end record;

   type Glyph_Command is record
      X         : Float := 0.0;
      Y         : Float := 0.0;
      Width     : Float := 0.0;
      Height    : Float := 0.0;
      U0        : Float := 0.0;
      V0        : Float := 0.0;
      U1        : Float := 0.0;
      V1        : Float := 0.0;
      Color     : Pixel_Color;
      Codepoint : Natural := 0;
   end record;

   Max_Text_Run_Codepoints : constant := 9;
   Max_Shaped_Glyphs_Per_Run : constant := 16;
   subtype Text_Run_Codepoint_Count is Natural range 0 .. Max_Text_Run_Codepoints;
   subtype Text_Run_Codepoint_Index is Positive range 1 .. Max_Text_Run_Codepoints;
   type Text_Run_Codepoint_Array is
     array (Text_Run_Codepoint_Index) of Natural;
   subtype Shaped_Glyph_Total is Natural range 0 .. Max_Shaped_Glyphs_Per_Run;
   subtype Shaped_Glyph_Index is Positive range 1 .. Max_Shaped_Glyphs_Per_Run;

   type Shaped_Glyph_Command is record
      Glyph_ID      : Natural := 0;
      Font_Index    : Natural := 0;
      Codepoint     : Natural := 0;
      Source_Index  : Text_Run_Codepoint_Count := 0;
      X_Offset      : Float := 0.0;
      Y_Offset      : Float := 0.0;
      X_Advance     : Float := 0.0;
      Y_Advance     : Float := 0.0;
   end record;

   type Shaped_Glyph_Array is array (Shaped_Glyph_Index) of Shaped_Glyph_Command;

   type Text_Run_Kind is
     (Simple_Glyph,
      Simple_Text,
      Combining_Cluster,
      Joined_Emoji_Cluster,
      Emoji_Modified_Cluster,
      Bidi_Text,
      Complex_Script,
      Ligature_Candidate,
      Invalid_Run);

   type Text_Run_Shape_Status is
     (Shape_Ok,
      Needs_Shaping_Backend,
      Invalid_Run);

   type Text_Run_Direction is
     (Direction_Neutral,
      Direction_Left_To_Right,
      Direction_Right_To_Left);

   type Text_Run_Script is
     (Script_Common,
      Script_Latin,
      Script_Greek,
      Script_Cyrillic,
      Script_Glagolitic,
      Script_Coptic,
      Script_Gothic,
      Script_Old_Italic,
      Script_Old_Persian,
      Script_Ugaritic,
      Script_Linear_B,
      Script_Cypriot,
      Script_Egyptian_Hieroglyphs,
      Script_Anatolian_Hieroglyphs,
      Script_Old_Permic,
      Script_Elbasan,
      Script_Caucasian_Albanian,
      Script_Mro,
      Script_Bassa_Vah,
      Script_Pahawh_Hmong,
      Script_Armenian,
      Script_Georgian,
      Script_Ethiopic,
      Script_Cherokee,
      Script_Canadian_Aboriginal,
      Script_Ogham,
      Script_Runic,
      Script_Tifinagh,
      Script_Vai,
      Script_Hebrew,
      Script_Arabic,
      Script_Syriac,
      Script_Thaana,
      Script_NKo,
      Script_Samaritan,
      Script_Mandaic,
      Script_Adlam,
      Script_Hanifi_Rohingya,
      Script_Imperial_Aramaic,
      Script_Palmyrene,
      Script_Nabataean,
      Script_Hatran,
      Script_Phoenician,
      Script_Lydian,
      Script_Avestan,
      Script_Inscriptional_Parthian,
      Script_Inscriptional_Pahlavi,
      Script_Psalter_Pahlavi,
      Script_Old_South_Arabian,
      Script_Old_North_Arabian,
      Script_Manichaean,
      Script_Tibetan,
      Script_Devanagari,
      Script_Bengali,
      Script_Gurmukhi,
      Script_Gujarati,
      Script_Oriya,
      Script_Tamil,
      Script_Telugu,
      Script_Kannada,
      Script_Malayalam,
      Script_Sinhala,
      Script_Brahmi,
      Script_Kaithi,
      Script_Chakma,
      Script_Mahajani,
      Script_Sharada,
      Script_Khojki,
      Script_Khudawadi,
      Script_Grantha,
      Script_Newa,
      Script_Tirhuta,
      Script_Siddham,
      Script_Modi,
      Script_Takri,
      Script_Ahom,
      Script_Dogra,
      Script_Warang_Citi,
      Script_Dives_Akuru,
      Script_Nandinagari,
      Script_Zanabazar_Square,
      Script_Soyombo,
      Script_Thai,
      Script_Lao,
      Script_Myanmar,
      Script_Mongolian,
      Script_Limbu,
      Script_Tai_Le,
      Script_New_Tai_Lue,
      Script_Khmer,
      Script_Balinese,
      Script_Sundanese,
      Script_Batak,
      Script_Lepcha,
      Script_Ol_Chiki,
      Script_Syloti_Nagri,
      Script_Phags_Pa,
      Script_Saurashtra,
      Script_Kayah_Li,
      Script_Rejang,
      Script_Buginese,
      Script_Tai_Tham,
      Script_Javanese,
      Script_Cham,
      Script_Tai_Viet,
      Script_Meetei_Mayek,
      Script_Hiragana,
      Script_Katakana,
      Script_Bopomofo,
      Script_Hangul,
      Script_Yi,
      Script_CJK,
      Script_Emoji,
      Script_Unknown);

   type Text_Run_Command is record
      X                : Float := 0.0;
      Y                : Float := 0.0;
      Cell_Width       : Float := 0.0;
      Cell_Height      : Float := 0.0;
      Cell_Span        : Positive := 1;
      Color            : Pixel_Color;
      Bold             : Boolean := False;
      Italic           : Boolean := False;
      Codepoints       : Text_Run_Codepoint_Array := (others => 0);
      Codepoint_Count  : Text_Run_Codepoint_Count := 0;
      Run_Kind         : Text_Run_Kind := Invalid_Run;
      Shape_Status     : Text_Run_Shape_Status := Invalid_Run;
      Direction        : Text_Run_Direction := Direction_Neutral;
      Script           : Text_Run_Script := Script_Common;
      Shaped_Glyphs    : Shaped_Glyph_Array := (others => <>);
      Shaped_Glyph_Count : Shaped_Glyph_Total := 0;
      Fallback_Glyphs  : Boolean := True;
   end record;

   type Rectangle_Array is array (Positive range <>) of Rectangle_Command;
   type Glyph_Array is array (Positive range <>) of Glyph_Command;
   type Text_Run_Array is array (Positive range <>) of Text_Run_Command;
   type Rectangle_Array_Access is access all Rectangle_Array;
   type Glyph_Array_Access is access all Glyph_Array;
   type Text_Run_Array_Access is access all Text_Run_Array;

   type Frame_Commands is record
      Width           : Natural := 0;
      Height          : Natural := 0;
      Rectangles      : Rectangle_Array_Access := null;
      Rectangle_Count : Natural := 0;
      Glyphs          : Glyph_Array_Access := null;
      Glyph_Count     : Natural := 0;
      Text_Runs       : Text_Run_Array_Access := null;
      Text_Run_Count  : Natural := 0;
      Atlas_Width     : Natural := 0;
      Atlas_Height    : Natural := 0;
      Atlas_Pixels    : System.Address := System.Null_Address;
      Atlas_Bytes     : Natural := 0;
      Atlas_Dirty     : Boolean := False;
   end record;
end Terminal.App.Render_Model;
