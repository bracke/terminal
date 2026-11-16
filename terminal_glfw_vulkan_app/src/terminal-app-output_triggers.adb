with Ada.Characters.Handling;

package body Terminal.App.Output_Triggers is
   use type Ada.Real_Time.Time;
   use type Terminal.Common.Bytes.Byte;
   use type Terminal.Core.Graphics_Stream_ID;

   function Text (Value : Text_Value) return String is
     (if Value.Length = 0 then "" else Value.Text (1 .. Value.Length));

   procedure Set (Target : out Text_Value; Value : String) is
   begin
      Target := (Capacity => Target.Capacity, others => <>);
      Target.Length := Value'Length;
      if Value'Length > 0 then
         Target.Text (1 .. Value'Length) := Value;
      end if;
   end Set;

   function Valid_Name (Value : String) return Boolean is
   begin
      if Value'Length not in 1 .. Max_Name_Length then return False; end if;
      for Ch of Value loop
         if Ch not in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' | '_' then
            return False;
         end if;
      end loop;
      return True;
   end Valid_Name;

   function Valid_Pattern (Value : String) return Boolean is
   begin
      if Value'Length not in 1 .. Max_Pattern_Length then return False; end if;
      for Ch of Value loop
         if Ch in ASCII.NUL .. ASCII.US or else Ch = ASCII.DEL then
            return False;
         end if;
      end loop;
      return True;
   end Valid_Pattern;

   function Find (Item : Registry; Rule_Name : String) return Natural is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Rule_Name);
   begin
      for I in 1 .. Item.Length loop
         if Ada.Characters.Handling.To_Lower (Text (Item.Rules (I).Rule_Name)) = Lower
         then
            return I;
         end if;
      end loop;
      return 0;
   end Find;

   procedure Apply
     (Item     : in out Registry;
      Name     : String;
      Pattern  : String;
      Accepted : out Boolean)
   is
      Index : Natural;
   begin
      Accepted := False;
      if not Valid_Name (Name) then return; end if;
      Index := Find (Item, Name);
      if Pattern = "" then
         if Index > 0 then
            for I in Index .. Item.Length - 1 loop
               Item.Rules (I) := Item.Rules (I + 1);
            end loop;
            Item.Rules (Item.Length) := (others => <>);
            Item.Length := Item.Length - 1;
         end if;
         Accepted := True;
      elsif not Valid_Pattern (Pattern) then
         return;
      else
         if Index = 0 then
            if Item.Length = Max_Triggers then return; end if;
            Item.Length := Item.Length + 1;
            Index := Item.Length;
            Set (Item.Rules (Index).Rule_Name, Name);
         end if;
         Set (Item.Rules (Index).Rule_Pattern, Pattern);
         Accepted := True;
      end if;
   end Apply;

   function Count (Item : Registry) return Natural is (Item.Length);

   function Name (Item : Registry; Index : Positive) return String is
   begin
      if Index > Item.Length then raise Constraint_Error; end if;
      return Text (Item.Rules (Index).Rule_Name);
   end Name;

   function Pattern (Item : Registry; Index : Positive) return String is
   begin
      if Index > Item.Length then raise Constraint_Error; end if;
      return Text (Item.Rules (Index).Rule_Pattern);
   end Pattern;

   procedure Append (Item : in out History; Value : Terminal.Common.Bytes.Byte) is
   begin
      Item.Data (Item.Next) := Value;
      Item.Next := (if Item.Next = Max_Pattern_Length then 1 else Item.Next + 1);
      if Item.Seen < Max_Pattern_Length then Item.Seen := Item.Seen + 1; end if;
   end Append;

   function Matches (Item : History; Value : String) return Boolean is
      Start : Positive;
      Slot : Positive;
   begin
      if Value'Length > Item.Seen then return False; end if;
      Start :=
        Positive
          (((Integer (Item.Next) - 1 - Value'Length + Max_Pattern_Length)
            mod Max_Pattern_Length) + 1);
      Slot := Start;
      for Ch of Value loop
         if Item.Data (Slot) /=
           Terminal.Common.Bytes.Byte (Character'Pos (Ch))
         then
            return False;
         end if;
         Slot := (if Slot = Max_Pattern_Length then 1 else Slot + 1);
      end loop;
      return True;
   end Matches;

   procedure Process
     (Item    : in out Detector;
      Rules   : Registry;
      Session : Terminal.App.Sessions.Session_Index;
      Stream  : Terminal.Core.Graphics_Stream_ID;
      Chunk   : Terminal.App.Queues.Byte_Chunk;
      Now     : Ada.Real_Time.Time;
      Fired   : out Fired_Set) is
   begin
      Fired := (others => False);
      if not Item.Stream_Valid (Session)
        or else Item.Streams (Session) /= Stream
      then
         Reset (Item, Session);
         Item.Streams (Session) := Stream;
         Item.Stream_Valid (Session) := True;
      end if;
      for Offset in 1 .. Chunk.Length loop
         Append (Item.Histories (Session), Chunk.Data (Offset));
         for Rule_Index in 1 .. Rules.Length loop
            if not Fired (Rule_Index)
              and then Matches
                (Item.Histories (Session),
                 Text (Rules.Rules (Rule_Index).Rule_Pattern))
              and then
                (Item.Last_Fired (Session, Rule_Index) = Ada.Real_Time.Time_First
                 or else Ada.Real_Time.To_Duration
                   (Now - Item.Last_Fired (Session, Rule_Index)) >= Cooldown)
            then
               Fired (Rule_Index) := True;
               Item.Last_Fired (Session, Rule_Index) := Now;
            end if;
         end loop;
      end loop;
   end Process;

   procedure Reset
     (Item : in out Detector;
      Session : Terminal.App.Sessions.Session_Index) is
   begin
      Item.Histories (Session) := (others => <>);
      for I in 1 .. Max_Triggers loop
         Item.Last_Fired (Session, I) := Ada.Real_Time.Time_First;
      end loop;
      Item.Stream_Valid (Session) := False;
      Item.Streams (Session) := 0;
   end Reset;
end Terminal.App.Output_Triggers;
