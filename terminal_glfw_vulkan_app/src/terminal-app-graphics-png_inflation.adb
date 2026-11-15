with Interfaces;

package body Terminal.App.Graphics.PNG_Inflation is
   use type Ada.Streams.Stream_Element_Offset;
   use type Data_Decode_Status;
   use type Interfaces.Unsigned_32;

   Adler_Modulus : constant Interfaces.Unsigned_32 := 65_521;

   procedure Fail
     (State : in out Decoder; Status : out Data_Decode_Status) is
   begin
      State.State := Failed;
      Status := Decode_Invalid_Byte;
   end Fail;

   overriding procedure Finalize (State : in out Decoder) is
   begin
      Terminal.App.Inflate_Filter.Close (State.Filter);
      State.State := Idle;
   end Finalize;

   procedure Initialize
     (State : in out Decoder;
      Compressed_Length, Expected_Length : Natural;
      Source : not null access function
        (Index : Positive) return Terminal.Common.Bytes.Byte;
      Status : out Data_Decode_Status)
   is
      CMF : constant Natural :=
        (if Compressed_Length >= 2 then Natural (Source (1)) else 0);
      FLG : constant Natural :=
        (if Compressed_Length >= 2 then Natural (Source (2)) else 0);
   begin
      Status := Decode_Ok;
      if State.State /= Idle
        or else Compressed_Length < 6
        or else CMF mod 16 /= 8
        or else (CMF / 16) > 7
        or else FLG / 32 mod 2 /= 0
        or else (CMF * 256 + FLG) mod 31 /= 0
      then
         Fail (State, Status);
         return;
      end if;

      State.Deflate_Pos := 3;
      State.Deflate_Last := Compressed_Length - 4;
      State.Expected_Length := Expected_Length;
      State.Produced := 0;
      State.Adler_A := 1;
      State.Adler_B := 0;
      State.Expected_Adler :=
        Interfaces.Shift_Left
          (Interfaces.Unsigned_32 (Source (Compressed_Length - 3)), 24)
        or Interfaces.Shift_Left
          (Interfaces.Unsigned_32 (Source (Compressed_Length - 2)), 16)
        or Interfaces.Shift_Left
          (Interfaces.Unsigned_32 (Source (Compressed_Length - 1)), 8)
        or Interfaces.Unsigned_32 (Source (Compressed_Length));
      State.State := Idle;
      State.Output_Last := State.Output'First - 1;
      State.Output_Pos := State.Output'First;
      declare
         Success : Boolean;
      begin
         Terminal.App.Inflate_Filter.Start
           (State.Filter, Terminal.App.Inflate_Filter.Raw_Deflate, Success);
         if not Success then
            Fail (State, Status);
         else
            State.State := Active;
         end if;
      end;
   exception
      when Constraint_Error =>
         Fail (State, Status);
   end Initialize;

   procedure Refill
     (State : in out Decoder;
      Source : not null access function
        (Index : Positive) return Terminal.Common.Bytes.Byte;
      Status : out Data_Decode_Status)
   is
   begin
      Status := Decode_Ok;
      if State.State in Ended | Failed then
         return;
      elsif Terminal.App.Inflate_Filter.Ended (State.Filter) then
         State.State := Ended;
         return;
      end if;

      while State.Output_Pos > State.Output_Last loop
         State.Output := (others => 0);
         State.Output_Last := State.Output'First - 1;
         State.Output_Pos := State.Output'First;

         if State.Deflate_Pos <= State.Deflate_Last then
            declare
               Count : constant Natural :=
                 Natural'Min
                   (State.Deflate_Last - State.Deflate_Pos + 1, 4096);
               Input : Ada.Streams.Stream_Element_Array
                 (1 .. Ada.Streams.Stream_Element_Offset (Count));
               Input_Last : Ada.Streams.Stream_Element_Offset;
               Success : Boolean;
            begin
               for I in Input'Range loop
                  Input (I) := Ada.Streams.Stream_Element
                    (Source
                       (State.Deflate_Pos
                        + Natural (I - Input'First)));
               end loop;
               Terminal.App.Inflate_Filter.Translate
                 (State.Filter, Input, Input_Last,
                  State.Output, State.Output_Last, Success);
               if not Success then
                  Fail (State, Status);
                  return;
               end if;
               if Input_Last >= Input'First then
                  State.Deflate_Pos := State.Deflate_Pos
                    + Natural (Input_Last - Input'First + 1);
               elsif State.Output_Last < State.Output'First then
                  Fail (State, Status);
                  return;
               end if;
               if Terminal.App.Inflate_Filter.Ended (State.Filter) then
                  State.State := Ended;
               end if;
            end;
         else
            declare
               Success : Boolean;
            begin
               Terminal.App.Inflate_Filter.Finish
                 (State.Filter, State.Output, State.Output_Last, Success);
               if not Success then
                  Fail (State, Status);
                  return;
               end if;
            end;
            if State.Output_Last < State.Output'First then
               if Terminal.App.Inflate_Filter.Ended (State.Filter) then
                  State.State := Ended;
                  return;
               end if;
               Fail (State, Status);
               return;
            end if;
         end if;

         exit when State.Output_Last >= State.Output'First;
      end loop;
   exception
      when Constraint_Error =>
         Fail (State, Status);
   end Refill;

   function Next
     (State : in out Decoder;
      Source : not null access function
        (Index : Positive) return Terminal.Common.Bytes.Byte;
      Status : out Data_Decode_Status) return Terminal.Common.Bytes.Byte
   is
   begin
      Status := Decode_Ok;
      if State.Output_Pos > State.Output_Last then
         Refill (State, Source, Status);
      end if;
      if Status /= Decode_Ok
        or else State.State = Failed
        or else State.Output_Pos > State.Output_Last
      then
         Fail (State, Status);
         return 0;
      end if;

      declare
         Value : constant Terminal.Common.Bytes.Byte :=
           Terminal.Common.Bytes.Byte (State.Output (State.Output_Pos));
      begin
         State.Output_Pos := State.Output_Pos + 1;
         State.Produced := State.Produced + 1;
         State.Adler_A :=
           (State.Adler_A + Interfaces.Unsigned_32 (Value)) mod Adler_Modulus;
         State.Adler_B :=
           (State.Adler_B + State.Adler_A) mod Adler_Modulus;
         if State.Produced > State.Expected_Length then
            Fail (State, Status);
         end if;
         return Value;
      end;
   end Next;

   procedure Finish
     (State : in out Decoder;
      Source : not null access function
        (Index : Positive) return Terminal.Common.Bytes.Byte;
      Status : out Data_Decode_Status) is
   begin
      Status := Decode_Ok;
      if State.State = Failed then
         Status := Decode_Invalid_Byte;
         return;
      end if;

      loop
         if State.Output_Pos <= State.Output_Last then
            Fail (State, Status);
            return;
         end if;
         exit when State.State = Ended;
         Refill (State, Source, Status);
         exit when Status /= Decode_Ok;
      end loop;

      if Status /= Decode_Ok
        or else State.Produced /= State.Expected_Length
        or else State.State /= Ended
        or else State.Deflate_Pos <= State.Deflate_Last
        or else
          (Interfaces.Shift_Left (State.Adler_B, 16) or State.Adler_A)
            /= State.Expected_Adler
      then
         Fail (State, Status);
      end if;
   end Finish;

   function Produced_Length (State : Decoder) return Natural is
     (State.Produced);
end Terminal.App.Graphics.PNG_Inflation;
