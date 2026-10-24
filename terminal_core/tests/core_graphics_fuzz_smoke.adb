with AUnit.Assertions;
with Ada.Environment_Variables;
with Interfaces;

with Terminal.Common;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Graphics_Fuzz_Smoke is
   use AUnit.Assertions;
   use type Interfaces.Unsigned_32;
   use type Terminal.Common.Code_Point;
   use type Terminal.Common.Bytes.Byte;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   T : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Status : Terminal.Core.Feed_Status;

   function Fuzz_Rounds return Positive is
   begin
      if not Ada.Environment_Variables.Exists
        ("TERMINAL_GRAPHICS_FUZZ_ROUNDS")
      then
         return 1_000;
      end if;
      return Positive'Min
        (10_000_000,
         Positive'Value
           (Ada.Environment_Variables.Value
              ("TERMINAL_GRAPHICS_FUZZ_ROUNDS")));
   exception
      when others =>
         return 1_000;
   end Fuzz_Rounds;

   function Fuzz_Seed return Interfaces.Unsigned_32 is
   begin
      if not Ada.Environment_Variables.Exists
        ("TERMINAL_GRAPHICS_FUZZ_SEED")
      then
         return 16#C001_D00D#;
      end if;
      return Interfaces.Unsigned_32'Value
        (Ada.Environment_Variables.Value ("TERMINAL_GRAPHICS_FUZZ_SEED"));
   exception
      when others =>
         return 16#C001_D00D#;
   end Fuzz_Seed;

   Round_Count : constant Positive := Fuzz_Rounds;
   State : Interfaces.Unsigned_32 := Fuzz_Seed;

   function Next return Interfaces.Unsigned_32 is
   begin
      State := State * 16#0019_660D# + 16#3C6E_F35F#;
      return State;
   end Next;

   procedure Drain_Bounded_Output is
      Response : Terminal.Common.Bytes.Byte_Array (1 .. 1_024);
      Last : Natural;
   begin
      while Terminal.Core.Pending_Graphics_Event_Count (T) > 0 loop
         Terminal.Core.Discard_Graphics_Event (T);
      end loop;
      while Terminal.Core.Pending_Response_Length (T) > 0 loop
         Terminal.Core.Read_Response (T, Response, Last);
         exit when Last = 0;
      end loop;
   end Drain_Bounded_Output;

   procedure Feed_Fragmented (Text : String) is
      Byte_Value : Terminal.Common.Bytes.Byte_Array (1 .. 1);
   begin
      for Ch of Text loop
         Byte_Value (1) :=
           Terminal.Common.Bytes.Byte (Character'Pos (Ch));
         Terminal.Core.Feed (T, Byte_Value, Status);
         Assert (Status /= Terminal.Core.Invalid_State,
                 "fragmented graphics parser entered an invalid state");
      end loop;
      Drain_Bounded_Output;
   end Feed_Fragmented;
begin
   Terminal.Core.Initialize (T, 24, 80, 256, Init);
   Assert (Init = Terminal.Core.Ok, "graphics fuzz initialize");
   Terminal.Core.Set_Graphics_Capabilities
     (T,
      (Kitty_Direct_RGB         => True,
       Kitty_Direct_RGBA        => True,
       Kitty_Indexed_RGB        => True,
       Kitty_Indexed_RGBA       => True,
       Kitty_Direct_PNG         => True,
       Kitty_Zlib_Compression   => True,
       Kitty_File_Transfer      => False,
       Kitty_Temporary_Transfer => False,
       Kitty_Shared_Memory      => False,
       Sixel                    => True,
       ITerm2_Inline_Images     => True,
       ITerm2_File_Downloads    => False));

   --  Exercise every parser boundary with malformed controls mixed with
   --  valid terminators.  These cases target huge numeric values, incomplete
   --  chunks, invalid Base64 and unfinished multipart transfers.
   Feed_Fragmented
     (ASCII.ESC & "_Gi=1,a=T,f=32,s=999999999999999999,v=2,m=1;%%%%"
      & ASCII.ESC & "\"
      & ASCII.ESC & "_Gm=0;A" & ASCII.ESC & "\"
      & ASCII.ESC & "P1;1q!999999999999999999~""1;1;999999999;999999999?"
      & ASCII.ESC & "\"
      & ASCII.ESC & "]1337;MultipartFile=inline=1" & ASCII.BEL
      & ASCII.ESC & "]1337;FilePart=%%%" & ASCII.BEL
      & ASCII.ESC & "]1337;FileEnd" & ASCII.BEL);

   --  Deterministic byte fuzzing is intentionally chunked at changing read
   --  boundaries.  Draining the public queues keeps this a parser/resource
   --  bound test rather than an accidental memory-pressure test.
   for Round in 1 .. Round_Count loop
      declare
         Length : constant Positive := Positive (Natural (Next mod 97) + 1);
         Data : Terminal.Common.Bytes.Byte_Array (1 .. Length);
      begin
         for I in Data'Range loop
            Data (I) := Terminal.Common.Bytes.Byte (Next mod 256);
         end loop;
         Terminal.Core.Feed (T, Data, Status);
         Assert
           (Status /= Terminal.Core.Invalid_State,
            "random graphics input entered an invalid parser state");
         if Status = Terminal.Core.Parser_Overflow then
            Terminal.Core.Feed
              (T,
               (1 => 16#1B#,
                2 => Terminal.Common.Bytes.Byte (Character'Pos ('\'))),
               Status);
         end if;
         Drain_Bounded_Output;
      end;
   end loop;

   --  Recovery must remain deterministic after arbitrary input.
   Terminal.Core.Initialize (T, 2, 8, 8, Init);
   Assert (Init = Terminal.Core.Ok, "graphics fuzz recovery initialize");
   Terminal.Core.Feed
     (T,
      (1 => Terminal.Common.Bytes.Byte (Character'Pos ('O')),
       2 => Terminal.Common.Bytes.Byte (Character'Pos ('K'))),
      Status);
   Assert (Status = Terminal.Core.Ok, "graphics fuzz recovery feed");
   declare
      Snapshot : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (Snapshot, 1, 1).Text.Code_Point = 16#4F#
         and then Terminal.Core.Cell_At (Snapshot, 1, 2).Text.Code_Point = 16#4B#,
         "graphics fuzz recovery text");
      Terminal.Core.Release (Snapshot);
   end;
   Terminal.Core.Finalize (T);
end Core_Graphics_Fuzz_Smoke;
