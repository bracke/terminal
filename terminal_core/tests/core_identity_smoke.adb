with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Common.Identity;
with Terminal.Core;

--  The private identity query, XTVERSION, in-band resize reports, and the
--  progressive keyboard enhancement stack.
procedure Core_Identity_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Resize_Status;

   T      : Terminal.Core.Terminal;
   Init   : Terminal.Core.Initialize_Status;
   Status : Terminal.Core.Feed_Status;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   --  Everything the terminal has queued to answer, as text.
   function Responses return String is
      Buffer : Byte_Array (1 .. 512);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      declare
         Text : String (1 .. Last);
      begin
         for I in Text'Range loop
            Text (I) := Character'Val (Buffer (I));
         end loop;
         return Text;
      end;
   end Responses;

   procedure Send (Text : String) is
   begin
      Terminal.Core.Feed (T, To_Bytes (Text), Status);
      Assert (Status = Terminal.Core.Ok, "feed " & Text (Text'First + 1 .. Text'Last));
   end Send;

   procedure Expect (Text : String; Answer : String; Label : String) is
   begin
      Send (Text);
      declare
         Got : constant String := Responses;
      begin
         Assert (Got = Answer, Label & ": got """ & Got & """");
      end;
   end Expect;

   ESC : constant Character := ASCII.ESC;
   CSI : constant String := ESC & "[";
   ST  : constant String := ESC & "\";
begin
   Terminal.Core.Initialize (T, 24, 80, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");
   Terminal.Core.Set_Cell_Pixel_Size (T, 10, 20);
   Terminal.Core.Set_Graphics_Capabilities
     (T, (Kitty_Direct_RGBA => True, Kitty_Shared_Memory => True, others => False));

   Expect
     (ESC & "]7701;q" & ST,
      ESC & "]7701;v=1;caps=kgfx,kgfx-shm,kbd,resize2048,osc52" & ST,
      "identity answers with its version and capabilities");
   Expect (ESC & "]7701;x" & ST, "", "only the query is answered");
   Terminal.Core.Set_Graphics_Capabilities
     (T,
      (Kitty_Direct_PNG => True, Kitty_Direct_JPEG => True, Kitty_Direct_GIF => True, others => False));
   Expect
     (ESC & "]7701;q" & ST,
      ESC & "]7701;v=1;caps=kgfx,kgfx-jpeg,kgfx-gif,kbd,resize2048,osc52" & ST,
      "the private JPEG and GIF formats are advertised");
   Expect
     (CSI & ">q",
      ESC & "P>|" & Terminal.Common.Identity.Program_Name & " "
      & Terminal.Common.Identity.Program_Version & ST,
      "XTVERSION");

   Expect (CSI & "?2048$p", CSI & "?2048;2$y", "in-band resize off by default");
   Expect (CSI & "?2048h", CSI & "48;24;80;480;800t", "turning it on reports the size at once");
   Expect (CSI & "?2048$p", CSI & "?2048;1$y", "in-band resize on");

   declare
      Resized : Terminal.Core.Resize_Status;
   begin
      Terminal.Core.Resize (T, 30, 100, Resized);
      Assert (Resized = Terminal.Core.Ok, "resize");
      Assert (Responses = CSI & "48;30;100;600;1000t", "a resize is reported in rows, columns, and pixels");
      Terminal.Core.Resize (T, 30, 100, Resized);
      Assert (Responses = "", "an unchanged size is not reported again");
   end;

   Terminal.Core.Set_Cell_Pixel_Size (T, 12, 24);
   Assert (Responses = CSI & "48;30;100;720;1200t", "a new cell size is reported");
   Expect (CSI & "?2048l", "", "turning it off");

   Assert (Terminal.Core.Modes (T).Keyboard_Flags = 0, "no keyboard enhancement at first");
   Expect (CSI & "?u", CSI & "?0u", "query flags");
   Send (CSI & ">1u");
   Assert (Terminal.Core.Modes (T).Keyboard_Flags = 1, "push disambiguate");
   Expect (CSI & "?u", CSI & "?1u", "query pushed flags");
   Send (CSI & ">31u");
   Expect (CSI & "?u", CSI & "?1u", "flags the terminal lacks are not taken");
   Send (CSI & "<u");
   Assert (Terminal.Core.Modes (T).Keyboard_Flags = 1, "pop back to the earlier entry");

   Send (CSI & "?1049h");
   Assert (Terminal.Core.Modes (T).Keyboard_Flags = 0, "the alternate screen has a stack of its own");
   Send (CSI & "=1;1u");
   Assert (Terminal.Core.Modes (T).Keyboard_Flags = 1, "set on the alternate screen");
   Send (CSI & "=1;3u");
   Assert (Terminal.Core.Modes (T).Keyboard_Flags = 0, "remove on the alternate screen");
   Send (CSI & "?1049l");
   Assert (Terminal.Core.Modes (T).Keyboard_Flags = 1, "the main screen kept its flags");
   Send (CSI & "<10u");
   Assert (Terminal.Core.Modes (T).Keyboard_Flags = 0, "popping more than there is empties the stack");

   Send (CSI & "s" & CSI & "u");
   Assert (Responses = "", "CSI u without parameters still restores the cursor");

   for I in 1 .. 20 loop
      Send (CSI & ">1u");
   end loop;
   Send (CSI & "<8u");
   Assert (Terminal.Core.Modes (T).Keyboard_Flags = 0, "a full stack drops its oldest entries");

   Send (CSI & ">1u" & ESC & "c");
   Assert (Terminal.Core.Modes (T).Keyboard_Flags = 0, "a full reset clears the stacks");
end Core_Identity_Smoke;
