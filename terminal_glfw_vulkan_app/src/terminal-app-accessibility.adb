with Ada.Strings.Unbounded;
with A11ykit;
with A11ykit.Provider;
with A11ykit.Tree;
with Terminal.Common;

package body Terminal.App.Accessibility is
   use Ada.Strings.Unbounded;
   use type Terminal.Core.Cell_Kind;

   procedure Append_UTF8
     (Text : in out Unbounded_String;
      Code : Terminal.Common.Code_Point)
   is
      Value : Natural := Natural (Code);
      procedure Put (Byte : Natural) is
      begin
         Append (Text, Character'Val (Byte));
      end Put;
   begin
      if Value = 0 or else Value > 16#10FFFF#
        or else Value in 16#D800# .. 16#DFFF#
      then
         Value := 16#FFFD#;
      end if;
      if Value <= 16#7F# then
         Put (Value);
      elsif Value <= 16#7FF# then
         Put (16#C0# + Value / 64);
         Put (16#80# + Value mod 64);
      elsif Value <= 16#FFFF# then
         Put (16#E0# + Value / 4_096);
         Put (16#80# + (Value / 64) mod 64);
         Put (16#80# + Value mod 64);
      else
         Put (16#F0# + Value / 262_144);
         Put (16#80# + (Value / 4_096) mod 64);
         Put (16#80# + (Value / 64) mod 64);
         Put (16#80# + Value mod 64);
      end if;
   end Append_UTF8;

   function Row_Text
     (Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive) return String
   is
      Result : Unbounded_String;
      Significant_Length : Natural := 0;
   begin
      for Col in 1 .. Positive (Snapshot.Cols) loop
         declare
            Cell : constant Terminal.Core.Cell_Content :=
              Terminal.Core.Cell_Content_At (Snapshot, Row, Col);
         begin
            if Cell.Kind = Terminal.Core.Wide_Continuation then
               null;
            elsif Cell.Kind = Terminal.Core.Character then
               Append_UTF8 (Result, Cell.Text.Code_Point);
               for I in 1 .. Cell.Text.Attachment_Count loop
                  Append_UTF8 (Result, Cell.Text.Attachments (I));
               end loop;
               Significant_Length := Length (Result);
            else
               Append (Result, ' ');
            end if;
         end;
      end loop;
      if Significant_Length = 0 then
         return "blank line";
      end if;
      return Slice (Result, 1, Significant_Length);
   end Row_Text;

   function Hash_Of
     (Snapshot : Terminal.Core.Render_Snapshot;
      Width, Height : Natural;
      Cell_Width, Cell_Height : Positive;
      Margin : Natural;
      Title, Status : String) return Content_Hash
   is
      Result : Content_Hash := 16#CBF29CE484222325#;
      procedure Mix (Value : Natural) is
      begin
         Result := (Result xor Content_Hash (Value)) * 16#100000001B3#;
      end Mix;
   begin
      Mix (Snapshot.Rows);
      Mix (Snapshot.Cols);
      Mix (Snapshot.Cursor.Row);
      Mix (Snapshot.Cursor.Col);
      Mix (Width);
      Mix (Height);
      Mix (Cell_Width);
      Mix (Cell_Height);
      Mix (Margin);
      for Ch of Title loop Mix (Character'Pos (Ch)); end loop;
      for Ch of Status loop Mix (Character'Pos (Ch)); end loop;
      for Row in 1 .. Snapshot.Rows loop
         for Col in 1 .. Snapshot.Cols loop
            declare
               Cell : constant Terminal.Core.Cell_Content :=
                 Terminal.Core.Cell_Content_At (Snapshot, Row, Col);
            begin
               Mix (Terminal.Core.Cell_Kind'Pos (Cell.Kind));
               if Cell.Kind = Terminal.Core.Character then
                  Mix (Natural (Cell.Text.Code_Point));
                  for I in 1 .. Cell.Text.Attachment_Count loop
                     Mix (Natural (Cell.Text.Attachments (I)));
                  end loop;
               end if;
            end;
         end loop;
      end loop;
      return Result;
   end Hash_Of;

   procedure Initialize
     (Item   : in out State;
      Window : GLFW_Vulkan.Windows.Window) is
   begin
      if Item.Started then return; end if;
      A11ykit.Provider.Start;
      A11ykit.Provider.Attach_Window
        (GLFW_Vulkan.Windows.Native_Handle (Window));
      Item.Started := True;
   exception
      when others =>
         begin
            A11ykit.Provider.Stop;
         exception
            when others => null;
         end;
         Item.Started := False;
   end Initialize;

   procedure Publish
     (Item        : in out State;
      Snapshot    : Terminal.Core.Render_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Cell_Width  : Positive;
      Cell_Height : Positive;
      Margin      : Natural;
      Title       : String;
      Status      : String)
   is
      use A11ykit;
      Hash : constant Content_Hash :=
        Hash_Of
          (Snapshot, Width, Height, Cell_Width, Cell_Height, Margin,
           Title, Status);
      Tree : A11ykit.Tree.Accessibility_Tree;
      Frame : constant Rectangle :=
        (X => 0, Y => 0, Width => Width, Height => Height);
      Content_Width : constant Natural :=
        Natural'Min
          ((if Width > Margin then Width - Margin else 0),
           Natural (Snapshot.Cols) * Cell_Width);
      Content_Height : constant Natural :=
        Natural'Min
          ((if Height > Margin then Height - Margin else 0),
           Natural (Snapshot.Rows) * Cell_Height);
      procedure Add
        (Role        : A11ykit.Role;
         Bounds      : Rectangle;
         Name        : String;
         Description : String;
         Parent      : Natural;
         Id          : Positive;
         Focused     : Boolean := False) is
      begin
         Tree.Nodes.Append
           (A11ykit.Tree.Node'(Node_Role => Role,
             Bounds => Bounds,
             Name => To_Unbounded_String (Name),
             Description => To_Unbounded_String (Description),
             Node_State =>
               (Enabled => True, Selected => Focused,
                Focused => Focused, Active => False),
             Parent => Parent));
         Tree.Ids.Append (Id);
         if Focused then Tree.Focused := Natural (Tree.Nodes.Last_Index); end if;
      end Add;
   begin
      if not Item.Started or else Snapshot.Rows = 0 or else Snapshot.Cols = 0
        or else (Item.Published and then Hash = Item.Last_Hash)
      then
         return;
      end if;
      Add
        (Role_Application, Frame, "Ada Terminal",
         "GPU terminal emulator", 0, 1);
      Add
        (Role_Window, Frame,
         (if Title = "" then "Terminal window" else Title),
         "Interactive terminal window", 1, 2);
      Add
        (Role_Pane,
         (X => Margin, Y => Margin,
          Width => Content_Width, Height => Content_Height),
         "Terminal content",
         Natural'Image (Snapshot.Rows) & " rows by"
           & Natural'Image (Snapshot.Cols) & " columns",
         2, 3);
      Add
        (Role_Table,
         (X => Margin, Y => Margin,
          Width => Content_Width, Height => Content_Height),
         "Terminal screen", "Visible terminal rows", 3, 5);
      for Row in 1 .. Positive (Snapshot.Rows) loop
         declare
            Row_Y : constant Natural := Margin + (Row - 1) * Cell_Height;
            Row_Height : constant Natural :=
              (if Row_Y >= Height then 0
               else Natural'Min (Cell_Height, Height - Row_Y));
         begin
            Add
              (Role_Table_Row,
               (X => Margin, Y => Row_Y,
                Width => Content_Width, Height => Row_Height),
               Row_Text (Snapshot, Row),
               "Terminal row" & Positive'Image (Row),
               4, 1_000 + Row,
               Snapshot.Cursor.Row = Row);
         end;
      end loop;
      if Status /= "" then
         Add
           (Role_Status,
            (X => 0,
             Y => (if Height > Cell_Height then Height - Cell_Height else 0),
             Width => Width,
             Height => Natural'Min (Height, Cell_Height)),
            Status, "Terminal interaction status", 2, 4);
      end if;
      A11ykit.Provider.Publish (Tree);
      Item.Last_Hash := Hash;
      Item.Published := True;
   exception
      when others =>
         Item.Published := False;
   end Publish;

   procedure Service (Item : in out State) is
      Request : A11ykit.Provider.Request;
   begin
      if not Item.Started then return; end if;
      A11ykit.Provider.Service;
      while A11ykit.Provider.Next_Request (Request) loop
         null;
      end loop;
   exception
      when others => null;
   end Service;

   procedure Set_Focused (Item : in out State; Focused : Boolean) is
   begin
      if Item.Started and then Item.Focused /= Focused then
         A11ykit.Provider.Set_Active (Focused);
         Item.Focused := Focused;
      end if;
   exception
      when others => null;
   end Set_Focused;

   procedure Finalize (Item : in out State) is
   begin
      if Item.Started then
         begin
            A11ykit.Provider.Set_Active (False);
         exception
            when others => null;
         end;
         begin
            A11ykit.Provider.Stop;
         exception
            when others => null;
         end;
      end if;
      Item.Started := False;
      Item.Focused := False;
      Item.Published := False;
      Item.Last_Hash := 0;
   end Finalize;

   function Status_Label (Item : State) return String is
     (if not Item.Started then "a11y=stopped"
      elsif A11ykit.Provider.Available then
        "a11y=" & A11ykit.Provider.Backend_Name
      elsif Item.Published then
        "a11y=" & A11ykit.Provider.Last_Publish_Backend_Name & " (fallback)"
      else "a11y=starting");
end Terminal.App.Accessibility;
