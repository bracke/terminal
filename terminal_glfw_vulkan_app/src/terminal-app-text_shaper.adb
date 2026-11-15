with Ada.Strings.Unbounded;

with Terminal.App.Fonts;
with Terminal.App.HarfBuzz;
with Terminal.App.Text_Properties_Data;
with Terminal.App.Text_Shaper_State;

package body Terminal.App.Text_Shaper is
   package RM renames Terminal.App.Render_Model;
   package HB renames Terminal.App.HarfBuzz;
   package Shape_Cache_Maps renames
     Terminal.App.Text_Shaper_State.Shape_Cache_Maps;
   subtype Shape_Cache_Entry is
     Terminal.App.Text_Shaper_State.Shape_Cache_Entry;
   package Text_Data renames Terminal.App.Text_Properties_Data;
   use type RM.Text_Run_Kind;
   use type RM.Text_Run_Script;
   use type HB.Load_Status;
   use type HB.Shape_Status;

   --  Shaping dominates the per-frame render cost, and the whole visible screen
   --  is reshaped every frame even when nothing changed (a cursor blink alone
   --  redraws it). Shaping is a pure function of a run's codepoints -- Direction,
   --  Script and Run_Kind are all derived from them -- and of the loaded faces,
   --  so memoise the fields Prepare produces, keyed on codepoints, style, and
   --  cell metrics. The cache is dropped whenever the face set changes
   --  (Configure_Font / Add_Fallback_Font), the only other input that can alter
   --  a run's shaping.
   Max_Shape_Cache_Entries : constant := 8192;

   procedure Clear_Shape_Cache (Item : in out Shaper) is
   begin
      Item.Data.Shape_Cache.Clear;
   end Clear_Shape_Cache;

   function Shape_Cache_Key (Run : RM.Text_Run_Command) return String is
      use Ada.Strings.Unbounded;
      Result : Unbounded_String;
   begin
      Append (Result, Float'Image (Run.Cell_Width));
      Append (Result, ':');
      Append (Result, Float'Image (Run.Cell_Height));
      Append (Result, ASCII.NUL);
      Append (Result, (if Run.Bold then 'B' else 'b'));
      Append (Result, (if Run.Italic then 'I' else 'i'));
      for I in 1 .. Run.Codepoint_Count loop
         declare
            CP : constant Natural := Run.Codepoints (I);
         begin
            Append (Result, Character'Val (CP mod 256));
            Append (Result, Character'Val ((CP / 256) mod 256));
            Append (Result, Character'Val ((CP / 65536) mod 256));
         end;
      end loop;
      return To_String (Result);
   end Shape_Cache_Key;

   procedure Configure_Font
     (Item   : in out Shaper;
      Path   : String;
      Status : out Backend_Status)
   is
      Load_Result : HB.Load_Status;
   begin
      HB.Load (Item.Data.Default_Face, Path, Load_Result);
      Item.Data.Default_Face_Tried := True;
      Item.Data.Default_Face_Loaded := Load_Result = HB.Loaded;
      for I in 1 .. Item.Data.Fallback_Face_Count loop
         HB.Reset (Item.Data.Fallback_Faces (I));
      end loop;
      Item.Data.Fallback_Face_Count := 0;
      Clear_Shape_Cache (Item);

      case Load_Result is
         when HB.Loaded =>
            Status := Backend_Ok;
         when HB.Invalid_Path =>
            Status := Backend_Unavailable;
         when HB.Load_Failed =>
            Status := Backend_Load_Failed;
      end case;
   end Configure_Font;

   procedure Add_Fallback_Font
     (Item   : in out Shaper;
      Path   : String;
      Status : out Backend_Status)
   is
      Load_Result : HB.Load_Status;
      Slot        : Natural;
   begin
      if Item.Data.Fallback_Face_Count >= Terminal.App.Fonts.Max_Fallback_Fonts then
         Status := Backend_Unavailable;
         return;
      end if;

      Slot := Item.Data.Fallback_Face_Count + 1;
      HB.Load (Item.Data.Fallback_Faces (Slot), Path, Load_Result);

      case Load_Result is
         when HB.Loaded =>
            Item.Data.Fallback_Face_Count := Slot;
            --  A new fallback face can change how previously-unshaped runs shape,
            --  so the memoised results are no longer valid.
            Clear_Shape_Cache (Item);
            Status := Backend_Ok;
         when HB.Invalid_Path =>
            Status := Backend_Unavailable;
         when HB.Load_Failed =>
            Status := Backend_Load_Failed;
      end case;
   end Add_Fallback_Font;

   function Backend_Available (Item : Shaper) return Boolean is
     (Item.Data.Default_Face_Loaded
      and then HB.Is_Loaded (Item.Data.Default_Face));

   function Backend_Status_Label (Status : Backend_Status) return String is
   begin
      case Status is
         when Backend_Ok =>
            return "Shaping backend ready";
         when Backend_Unavailable =>
            return "Shaping backend unavailable";
         when Backend_Load_Failed =>
            return "Shaping backend load failed";
      end case;
   end Backend_Status_Label;

   function Shape_Status_Label (Status : Shape_Status) return String is
   begin
      case Status is
         when RM.Shape_Ok =>
            return "Text shaping complete";
         when RM.Needs_Shaping_Backend =>
            return "Text shaping backend needed";
         when RM.Invalid_Run =>
            return "Text shaping skipped; invalid run";
      end case;
   end Shape_Status_Label;

   procedure Ensure_Default_Backend (Item : in out Shaper) is
      Status : Backend_Status;
   begin
      if not Item.Data.Default_Face_Tried then
         Configure_Font
           (Item   => Item,
            Path   => Terminal.App.Fonts.Default_Font_Path,
            Status => Status);
      end if;
   end Ensure_Default_Backend;

   function Generated_Script (C : Natural) return RM.Text_Run_Script is
      First : Natural := Text_Data.Script_Intervals'First;
      Last  : Natural := Text_Data.Script_Intervals'Last;
   begin
      while First <= Last loop
         declare
            Middle : constant Natural := First + (Last - First) / 2;
            Item   : Text_Data.Script_Interval renames
              Text_Data.Script_Intervals (Middle);
         begin
            if C < Item.First then
               if Middle = Text_Data.Script_Intervals'First then
                  return RM.Script_Unknown;
               end if;
               Last := Middle - 1;
            elsif C > Item.Last then
               First := Middle + 1;
            else
               return Item.Script;
            end if;
         end;
      end loop;
      return RM.Script_Unknown;
   end Generated_Script;

   function In_Intervals
     (C     : Natural;
      Items : Text_Data.Interval_Array) return Boolean
   is
      First : Natural := Items'First;
      Last  : Natural := Items'Last;
   begin
      while First <= Last loop
         declare
            Middle : constant Natural := First + (Last - First) / 2;
         begin
            if C < Items (Middle).First then
               if Middle = Items'First then
                  return False;
               end if;
               Last := Middle - 1;
            elsif C > Items (Middle).Last then
               First := Middle + 1;
            else
               return True;
            end if;
         end;
      end loop;
      return False;
   end In_Intervals;

   function Generated_RTL (C : Natural) return Boolean is
     (In_Intervals (C, Text_Data.RTL_Intervals));

   function Generated_Emoji (C : Natural) return Boolean is
     (In_Intervals (C, Text_Data.Emoji_Intervals));

   function Is_Emoji_Script_Scalar (C : Natural) return Boolean is
     (Generated_Emoji (C)
      and then C not in Character'Pos ('0') .. Character'Pos ('9')
      and then C /= Character'Pos ('#')
      and then C /= Character'Pos ('*'));

   function Is_Combining_Or_Format (C : Natural) return Boolean is
     ((C in 16#0300# .. 16#036F#)
      or else (C in 16#1AB0# .. 16#1AFF#)
      or else (C in 16#1DC0# .. 16#1DFF#)
      or else (C in 16#20D0# .. 16#20FF#)
      or else (C in 16#FE20# .. 16#FE2F#)
      or else (C in 16#FE00# .. 16#FE0F#)
      or else C = 16#200C#
      or else (C in 16#E0020# .. 16#E007F#));

   function Is_ZWJ (C : Natural) return Boolean is
     (C = 16#200D#);

   function Is_Emoji_Modifier (C : Natural) return Boolean is
     (C in 16#1F3FB# .. 16#1F3FF#);

   function Is_LTR_Directional_Control (C : Natural) return Boolean is
     (C = 16#200E#
      or else C = 16#202A#
      or else C = 16#202D#
      or else C = 16#2066#);

   function Is_RTL_Directional_Control (C : Natural) return Boolean is
     (C = 16#200F#
      or else C = 16#202B#
      or else C = 16#202E#
      or else C = 16#2067#);

   function Is_Neutral_Bidi_Control (C : Natural) return Boolean is
     (C = 16#202C#
      or else C = 16#2068#
      or else C = 16#2069#);

   function Is_Bidi_Control (C : Natural) return Boolean is
     (Is_LTR_Directional_Control (C)
      or else Is_RTL_Directional_Control (C)
      or else Is_Neutral_Bidi_Control (C));

   function Is_Complex_Script (C : Natural) return Boolean is
      First : Natural := Text_Data.Script_Intervals'First;
      Last  : Natural := Text_Data.Script_Intervals'Last;
   begin
      while First <= Last loop
         declare
            Middle : constant Natural := First + (Last - First) / 2;
            Item   : constant Text_Data.Script_Interval :=
              Text_Data.Script_Intervals (Middle);
         begin
            if C < Item.First then
               if Middle = Text_Data.Script_Intervals'First then
                  return False;
               end if;
               Last := Middle - 1;
            elsif C > Item.Last then
               First := Middle + 1;
            else
               return Item.Complex_Shaping;
            end if;
         end;
      end loop;
      return False;
   end Is_Complex_Script;

   function Is_ASCII_Digit (C : Natural) return Boolean is
     (C in Character'Pos ('0') .. Character'Pos ('9'));
   function Has_Common_Ligature_Sequence (Run : RM.Text_Run_Command) return Boolean is
   begin
      if Run.Codepoint_Count < 2 then
         return False;
      end if;

      for I in 1 .. Run.Codepoint_Count - 1 loop
         if Run.Codepoints (I) = Character'Pos ('f') then
            if Run.Codepoints (I + 1) = Character'Pos ('f')
              or else Run.Codepoints (I + 1) = Character'Pos ('i')
              or else Run.Codepoints (I + 1) = Character'Pos ('l')
            then
               return True;
            end if;
         end if;
      end loop;

      return False;
   end Has_Common_Ligature_Sequence;

   function Classify (Run : RM.Text_Run_Command) return Run_Kind is
      Saw_Combining : Boolean := False;
   begin
      if Run.Codepoint_Count = 0 then
         return RM.Invalid_Run;
      end if;

      for I in 1 .. Run.Codepoint_Count loop
         declare
            C : constant Natural := Run.Codepoints (I);
         begin
            if C > 16#10FFFF# then
               return RM.Invalid_Run;
            elsif Is_ASCII_Digit (C) then
               null;
            elsif Generated_RTL (C) or else Is_Bidi_Control (C) then
               return RM.Bidi_Text;
            elsif Is_ZWJ (C) then
               return RM.Joined_Emoji_Cluster;
            elsif Is_Emoji_Modifier (C) then
               return RM.Emoji_Modified_Cluster;
            elsif Is_Complex_Script (C) then
               return RM.Complex_Script;
            elsif Is_Combining_Or_Format (C) then
               Saw_Combining := True;
            end if;
         end;
      end loop;

      if Saw_Combining then
         return RM.Combining_Cluster;
      elsif Has_Common_Ligature_Sequence (Run) then
         return RM.Ligature_Candidate;
      elsif Run.Codepoint_Count > 1 then
         return RM.Simple_Text;
      else
         return RM.Simple_Glyph;
      end if;
   end Classify;

   function Requires_Backend (Kind : Run_Kind) return Boolean is
     (Kind not in RM.Simple_Glyph | RM.Simple_Text);

   function Has_Notdef_Glyph (Run : RM.Text_Run_Command) return Boolean is
   begin
      for I in 1 .. Run.Shaped_Glyph_Count loop
         if Run.Shaped_Glyphs (I).Glyph_ID = 0 then
            return True;
         end if;
      end loop;

      return False;
   end Has_Notdef_Glyph;

   procedure Shape_With_Configured_Faces
     (Item   : Shaper;
      Run    : in out RM.Text_Run_Command;
      Status : out HB.Shape_Status)
   is
      Candidate : RM.Text_Run_Command;
      Candidate_Status : HB.Shape_Status;
      Primary_Result : RM.Text_Run_Command;
      Primary_Status : HB.Shape_Status := HB.Not_Loaded;
   begin
      if Backend_Available (Item) then
         Candidate := Run;
         HB.Shape (Item.Data.Default_Face, 0, Candidate, Candidate_Status);
         if Candidate_Status = HB.Shaped and then not Has_Notdef_Glyph (Candidate) then
            Run := Candidate;
            Status := HB.Shaped;
            return;
         end if;

         Primary_Result := Candidate;
         Primary_Status := Candidate_Status;
      end if;

      for I in 1 .. Item.Data.Fallback_Face_Count loop
         if HB.Is_Loaded (Item.Data.Fallback_Faces (I)) then
            Candidate := Run;
            HB.Shape
              (Item.Data.Fallback_Faces (I), I, Candidate, Candidate_Status);
            if Candidate_Status = HB.Shaped
              and then not Has_Notdef_Glyph (Candidate)
            then
               Run := Candidate;
               Status := HB.Shaped;
               return;
            end if;
         end if;
      end loop;

      if Primary_Status = HB.Shaped then
         Run := Primary_Result;
         Status :=
           (if Has_Notdef_Glyph (Primary_Result)
            then HB.Shape_Failed
            else HB.Shaped);
      else
         Status := Primary_Status;
      end if;
   end Shape_With_Configured_Faces;

   function Script_Of_Codepoint
     (Codepoint : Natural) return RM.Text_Run_Script;

   function Direction_Of
     (Run : RM.Text_Run_Command) return RM.Text_Run_Direction
   is
   begin
      for I in 1 .. Run.Codepoint_Count loop
         declare
            C : constant Natural := Run.Codepoints (I);
            Script : constant RM.Text_Run_Script := Script_Of_Codepoint (C);
         begin
            if Generated_RTL (C) or else Is_RTL_Directional_Control (C) then
               return RM.Direction_Right_To_Left;
            elsif Is_LTR_Directional_Control (C)
              or else Is_ASCII_Digit (C)
              or else Script not in RM.Script_Common | RM.Script_Unknown
            then
               return RM.Direction_Left_To_Right;
            end if;
         end;
      end loop;
      return RM.Direction_Neutral;
   end Direction_Of;

   function Script_Of_Codepoint
     (Codepoint : Natural) return RM.Text_Run_Script
   is
   begin
      if Codepoint > 16#10FFFF# then
         return RM.Script_Unknown;
      --  Unicode assigns the Phaistos Disc block to Common because it has no
      --  ISO 15924 Script property.  The renderer keeps it as a distinct
      --  shaping diagnostic category, so preserve that local pseudo-script.
      elsif Codepoint in 16#101D0# .. 16#101FF# then
         return RM.Script_Phaistos_Disc;
      elsif Is_Emoji_Script_Scalar (Codepoint) then
         return RM.Script_Emoji;
      else
         return Generated_Script (Codepoint);
      end if;
   end Script_Of_Codepoint;

   function Script_Of (Run : RM.Text_Run_Command) return RM.Text_Run_Script is
      Script : RM.Text_Run_Script;
   begin
      for I in 1 .. Run.Codepoint_Count loop
         Script := Script_Of_Codepoint (Run.Codepoints (I));
         if Script /= RM.Script_Common then
            return Script;
         end if;
      end loop;

      return RM.Script_Common;
   end Script_Of;

   procedure Properties_Of
     (Codepoint : Natural;
      Direction : out RM.Text_Run_Direction;
      Script    : out RM.Text_Run_Script)
   is
   begin
      Script := Script_Of_Codepoint (Codepoint);
      if Generated_RTL (Codepoint)
        or else Is_RTL_Directional_Control (Codepoint)
      then
         Direction := RM.Direction_Right_To_Left;
      elsif Is_LTR_Directional_Control (Codepoint)
        or else Is_ASCII_Digit (Codepoint)
        or else Script not in RM.Script_Common | RM.Script_Unknown
        or else Is_Complex_Script (Codepoint)
      then
         Direction := RM.Direction_Left_To_Right;
      else
         Direction := RM.Direction_Neutral;
      end if;
   end Properties_Of;

   procedure Prepare
     (Item   : in out Shaper;
      Run    : in out RM.Text_Run_Command;
      Status : out Shape_Status)
   is
      Key       : constant String := Shape_Cache_Key (Run);
      Cached    : constant Shape_Cache_Maps.Cursor :=
        Item.Data.Shape_Cache.Find (Key);
      Kind      : Run_Kind;
      HB_Status : HB.Shape_Status;
   begin
      if Shape_Cache_Maps.Has_Element (Cached) then
         declare
            E : constant Shape_Cache_Entry := Shape_Cache_Maps.Element (Cached);
         begin
            Run.Run_Kind           := E.Run_Kind;
            Run.Shape_Status       := E.Shape_Status;
            Run.Direction          := E.Direction;
            Run.Script             := E.Script;
            Run.Shaped_Glyphs      := E.Shaped_Glyphs;
            Run.Shaped_Glyph_Count := E.Shaped_Glyph_Count;
            Run.Fallback_Glyphs    := E.Fallback_Glyphs;
            Status                 := E.Shape_Status;
            return;
         end;
      end if;

      Kind := Classify (Run);
      Run.Run_Kind := Kind;
      Run.Direction := Direction_Of (Run);
      Run.Script := Script_Of (Run);
      Run.Shaped_Glyphs := (others => <>);
      Run.Shaped_Glyph_Count := 0;

      if Kind = RM.Invalid_Run then
         Run.Shape_Status := RM.Invalid_Run;
         Run.Fallback_Glyphs := True;
         Status := RM.Invalid_Run;
      else
         Ensure_Default_Backend (Item);
         if Backend_Available (Item) then
            Shape_With_Configured_Faces (Item, Run, HB_Status);
         else
            HB_Status := HB.Not_Loaded;
         end if;

         if HB_Status = HB.Shaped then
            Run.Shape_Status := RM.Shape_Ok;
            Run.Fallback_Glyphs := False;
            Status := RM.Shape_Ok;
         elsif Requires_Backend (Kind) then
            Run.Shape_Status := RM.Needs_Shaping_Backend;
            Run.Fallback_Glyphs := True;
            Run.Shaped_Glyphs := (others => <>);
            Run.Shaped_Glyph_Count := 0;
            Status := RM.Needs_Shaping_Backend;
         else
            Run.Shape_Status := RM.Shape_Ok;
            Run.Fallback_Glyphs := True;
            Run.Shaped_Glyphs := (others => <>);
            Run.Shaped_Glyph_Count := 0;
            Status := RM.Shape_Ok;
         end if;
      end if;

      --  Memoise the result so the same run (the norm on a screen redrawn every
      --  frame) is not reshaped again. Bounded: once full the cache is dropped
      --  wholesale rather than grown without limit.
      if Natural (Item.Data.Shape_Cache.Length) >= Max_Shape_Cache_Entries then
         Item.Data.Shape_Cache.Clear;
      end if;
      Item.Data.Shape_Cache.Insert
        (Key,
         (Run_Kind           => Run.Run_Kind,
          Shape_Status       => Run.Shape_Status,
          Direction          => Run.Direction,
          Script             => Run.Script,
          Shaped_Glyphs      => Run.Shaped_Glyphs,
          Shaped_Glyph_Count => Run.Shaped_Glyph_Count,
          Fallback_Glyphs    => Run.Fallback_Glyphs));
   end Prepare;

   procedure Reset (Item : in out Shaper) is
   begin
      Item.Data.Shape_Cache.Clear;
      HB.Reset (Item.Data.Default_Face);
      for I in 1 .. Item.Data.Fallback_Face_Count loop
         HB.Reset (Item.Data.Fallback_Faces (I));
      end loop;
      Item.Data.Fallback_Face_Count := 0;
      Item.Data.Default_Face_Loaded := False;
      Item.Data.Default_Face_Tried := False;
   end Reset;

   overriding procedure Finalize (Item : in out Shaper) is
   begin
      Reset (Item);
   end Finalize;
end Terminal.App.Text_Shaper;
