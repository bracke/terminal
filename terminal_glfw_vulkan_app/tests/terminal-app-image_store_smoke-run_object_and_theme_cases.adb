separate (Terminal.App.Image_Store_Smoke)
procedure Run_Object_And_Theme_Cases is
   Container   : aliased Store.Store;
   Original    : Store.Image_Object_Access := null;
   Replacement : Store.Image_Object_Access := null;
   Pixel       : Terminal.Common.Bytes.Byte_Array (1 .. 4);
   Valid       : Boolean;
begin
   Store.Create_Object (Original);
   Store.Create_Object (Replacement);
   Store.Link_New (Container, Original);
   declare
      Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'
          (1 => 16#FF#, 2 => 0, 3 => 0, 4 => 16#FF#);
   begin
      Install_Root
        (Container, Original, Stream_ID => 0, ID => 1, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 1, Pixel_Height => 1,
         Decoded_Length => 4, Row_Stride => 4, Usage_Hint => 0,
         Data => Data);
   end;
   declare
      Rejected : Boolean := False;
      Other : Store.Store;
   begin
      begin
         Store.Link_New (Container, Original);
      exception
         when Program_Error =>
            Rejected := True;
      end;
      Assert (Rejected, "an owned object cannot be linked twice");
      Rejected := False;
      begin
         Store.Link_New (Other, Original);
      exception
         when Program_Error =>
            Rejected := True;
      end;
      Assert (Rejected, "an object cannot be linked into another store");
   end;
   Assert
     (Store.First (Container) = Original
      and then Store.Object_Count (Container) = 1
      and then Store.Byte_Count (Container) = 4,
      "new object is owned and accounted");
   declare
      Borrow : Store.Data_Borrow;
      Root_Copy : Terminal.Common.Bytes.Byte_Array (1 .. 4);
      Frame_Found : Boolean := False;
      Frame_Length : Natural := 0;
      procedure Inspect_Frame
        (Data : Terminal.Common.Bytes.Byte_Array) is
      begin
         Frame_Found := True;
         Frame_Length := Data'Length;
      end Inspect_Frame;
   begin
      Store.Borrow (Borrow, Original);
      Store.Copy_Root_Data (Borrow, Root_Copy);
      Store.Visit_Borrowed_Frame_Data
        (Borrow, 1, Inspect_Frame'Access);
      Assert
        (Frames.Exists (Original, 1)
         and then Frame_Found
         and then Frame_Length = Root_Copy'Length,
         "root animation frame is resolved by the store");
      Frames.Copy_To_RGBA (Original, 1, Pixel, Valid);
      Assert
        (Valid and then Pixel = Root_Copy,
         "store copies the root RGBA frame");
   end;
   Assert
     (Original.Pixel_Width = 1 and then Original.Pixel_Height = 1,
      "installed dimensions are exposed read-only");

   Store.Link_Replacement (Container, Replacement, Original);
   declare
      Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 8 => 0);
   begin
      Install_Root
        (Container, Replacement, Stream_ID => 0, ID => 1, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 2, Pixel_Height => 1,
         Decoded_Length => 8, Row_Stride => 8, Usage_Hint => 0,
         Data => Data);
   end;
   declare
      Duplicate : Store.Image_Object_Access := null;
      Rejected : Boolean := False;
   begin
      Store.Create_Object (Duplicate);
      begin
         Store.Link_Replacement (Container, Duplicate, Original);
      exception
         when Program_Error =>
            Rejected := True;
      end;
      Assert (Rejected, "only one replacement may target an object");
      Store.Release_Unowned_Object (Duplicate);
   end;
   Assert
     (Store.Object_Count (Container) = 1
      and then Store.Byte_Count (Container) = 12,
      "replacement accounting uses owned allocations, not metadata");

   declare
      Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 1);
      Operation : Store.Theme_Operation_Access := null;
      Rejected : Boolean := False;
   begin
      begin
         Create_Theme
           ((Raw_Format => 32,
             Data_Width => 2,
             Data_Height => 1,
             Data_Row_Stride_Bytes => 8,
             others => <>),
            Data,
            Operation);
      exception
         when Constraint_Error =>
            Rejected := True;
      end;
      Assert
        (Rejected and then Data /= null,
         "theme creation rejects truncated pixel storage without consuming it");
   end;

   declare
      Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 1);
      Operation : Store.Theme_Operation_Access := null;
      Rejected : Boolean := False;
   begin
      begin
         Create_Theme
           ((Raw_Format            => 32,
             Data_Width            => 1,
             Data_Height           => 1,
             Data_Row_Stride_Bytes => 4,
             Composition_Mode      => 2,
             others                => <>),
            Data,
            Operation);
      exception
         when Constraint_Error =>
            Rejected := True;
      end;
      Assert
        (Rejected and then Data /= null and then Operation = null,
         "theme creation rejects unsupported data composition modes");
   end;

   declare
      Data : Terminal.App.Image_Data.Image_Data_Access := null;
      Operation : Store.Theme_Operation_Access := null;
      Rejected : Boolean := False;
   begin
      begin
         Create_Theme
           ((Is_Composition => True, others => <>), Data, Operation);
      exception
         when Constraint_Error =>
            Rejected := True;
      end;
      Assert
        (Rejected and then Operation = null,
         "theme creation rejects incomplete composition descriptors");
   end;

   Store.Delete_Replacement (Container, Replacement);
   Assert
     (Replacement = null
      and then Store.First (Container) = Original
      and then Store.Object_Count (Container) = 1
      and then Store.Byte_Count (Container) = 4,
      "replacement rollback restores store accounting");

   declare
      Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 1);
      Operation : Store.Theme_Operation_Access;
      Duplicate : Store.Theme_Operation_Access;
      Rejected : Boolean := False;
      Transaction : Themes.Append_Transaction (Container'Access);
      Duplicate_Transaction : Themes.Append_Transaction (Container'Access);
   begin
      Create_Theme
        (RGBA_Theme_Description (1), Data, Operation);
      Duplicate := Operation;
      Themes.Start (Transaction, Original, Operation);
      Themes.Commit (Transaction);
      Assert
        (Operation = null
         and then Themes.Count (Original) = 1
         and then Store.Byte_Count (Container) = 8,
         "theme history adoption transfers ownership and accounting");
      begin
         Themes.Start (Duplicate_Transaction, Original, Duplicate);
      exception
         when Program_Error =>
            Rejected := True;
      end;
      Assert
        (Rejected and then Duplicate /= null,
         "theme history rejects an already-owned operation node");
   end;
   declare
      Borrow : Store.Data_Borrow;
      Position : Themes.Cursor;
      Clear_Rejected : Boolean := False;
      Theme_Length : Natural := 0;
      Visited : Boolean := False;
      procedure Inspect_Theme
        (Data : Terminal.Common.Bytes.Byte_Array) is
      begin
         Theme_Length := Data'Length;
      end Inspect_Theme;
   begin
      Store.Borrow (Borrow, Original);
      Position := Themes.First (Borrow);
      if Themes.Has_Element (Position) then
         Visited := Themes.Visit_Data
           (Borrow, Position, Inspect_Theme'Access);
      end if;
      Assert
        (Themes.Has_Element (Position)
         and then Visited
         and then Theme_Length = 4,
         "theme bytes are available only through a pinned object borrow");
      begin
         Themes.Clear (Container, Original);
      exception
         when Program_Error =>
            Clear_Rejected := True;
      end;
      Assert
        (Clear_Rejected and then Themes.Count (Original) = 1,
         "theme mutation rejects an active data borrow");
   end;
   declare
      Other : Store.Image_Object_Access := null;
      Root : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 0);
      Theme_Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 1);
      Operation : Store.Theme_Operation_Access := null;
      Transaction : Themes.Append_Transaction (Container'Access);
      Theme_Rejected : Boolean := False;
      Frame_Rejected : Boolean := False;
      Expired_Theme_Rejected : Boolean := False;
      Expired_Frame_Rejected : Boolean := False;
      Expired_Theme_Position : Themes.Cursor;
      Expired_Frame_Position : Frames.Cursor;
   begin
      Store.Create_Object (Other);
      Store.Link_New (Container, Other);
      Install_Root
        (Container, Other, Stream_ID => 0, ID => 2, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 1, Pixel_Height => 1,
         Decoded_Length => 4, Row_Stride => 4, Usage_Hint => 0,
         Data => Root);
      Create_Theme
        (RGBA_Theme_Description (1), Theme_Data, Operation);
      Themes.Start (Transaction, Other, Operation);
      Themes.Commit (Transaction);
      declare
         Original_Borrow : Store.Data_Borrow;
         Other_Borrow : Store.Data_Borrow;
         Theme_Position : Themes.Cursor;
         Frame_Position : Frames.Cursor;
      begin
         Store.Borrow (Original_Borrow, Original);
         Store.Borrow (Other_Borrow, Other);
         Theme_Position := Themes.First (Original_Borrow);
         Frame_Position := Frames.First (Original_Borrow);
         Expired_Theme_Position := Theme_Position;
         Expired_Frame_Position := Frame_Position;
         begin
            declare
               Ignored : constant Store.Theme_Operation_Descriptor :=
                 Themes.Descriptor (Other_Borrow, Theme_Position);
            begin
               null;
            end;
         exception
            when Program_Error => Theme_Rejected := True;
         end;
         begin
            declare
               Ignored : constant Frames.Frame_Descriptor :=
                 Frames.Descriptor (Other_Borrow, Frame_Position);
            begin
               null;
            end;
         exception
            when Program_Error => Frame_Rejected := True;
         end;
      end;
      declare
         New_Borrow : Store.Data_Borrow;
      begin
         Store.Borrow (New_Borrow, Original);
         begin
            declare
               Ignored : constant Store.Theme_Operation_Descriptor :=
                 Themes.Descriptor (New_Borrow, Expired_Theme_Position);
            begin
               null;
            end;
         exception
            when Program_Error => Expired_Theme_Rejected := True;
         end;
         begin
            declare
               Ignored : constant Frames.Frame_Descriptor :=
                 Frames.Descriptor (New_Borrow, Expired_Frame_Position);
            begin
               null;
            end;
         exception
            when Program_Error => Expired_Frame_Rejected := True;
         end;
      end;
      Assert
        (Theme_Rejected
         and then Frame_Rejected
         and then Expired_Theme_Rejected
         and then Expired_Frame_Rejected,
         "image cursors remain bound to their originating active borrow");
      Store.Delete_Object (Container, Other);
   end;
   Themes.Clear (Container, Original);
   Assert
     (Themes.Count (Original) = 0
      and then Store.Byte_Count (Container) = 4,
      "clearing theme history restores accounting");

   declare
      Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#31#);
      Operation : Store.Theme_Operation_Access;
      Transaction : Themes.Append_Transaction (Container'Access);
      Clear_Rejected : Boolean := False;
      Delete_Rejected : Boolean := False;
   begin
      Create_Theme
        (RGBA_Theme_Description (1), Data, Operation);
      Themes.Start (Transaction, Original, Operation);
      Assert
        (Operation = null
         and then Themes.Count (Original) = 1
         and then Store.Byte_Count (Container) = 8,
         "theme append transaction publishes provisional accounting");
      begin
         Themes.Clear (Container, Original);
      exception
         when Program_Error => Clear_Rejected := True;
      end;
      begin
         Store.Delete_Object (Container, Original);
      exception
         when Program_Error => Delete_Rejected := True;
      end;
      Assert
        (Clear_Rejected and then Delete_Rejected and then Original /= null,
         "active theme transactions lock history and object lifetime");
      Themes.Rollback (Transaction);
      Assert
        (Themes.Count (Original) = 0
         and then Store.Byte_Count (Container) = 4,
         "theme append rollback restores ownership and accounting");
   end;

   declare
      First_Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#34#);
      Second_Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#35#);
      Head, Tail, Operation : Store.Theme_Operation_Access := null;
      Transaction : Themes.Append_Transaction (Container'Access);
   begin
      Create_Theme
        (RGBA_Theme_Description (1), First_Data, Operation);
      Themes.Append_Unowned (Head, Tail, Operation);
      Create_Theme
        (RGBA_Theme_Description (2), Second_Data, Operation);
      Themes.Append_Unowned (Head, Tail, Operation);
      Assert
        (Themes.Unowned_Length (Head) = 8,
         "unowned theme-list length includes the complete suffix");
      Themes.Start (Transaction, Original, Head);
      Assert
        (Head = null
         and then Themes.Count (Original) = 2
         and then Store.Byte_Count (Container) = 12,
         "theme transaction publishes a prepared history suffix atomically");
      Themes.Rollback (Transaction);
      Assert
        (Themes.Count (Original) = 0
         and then Store.Byte_Count (Container) = 4,
         "theme suffix rollback restores ownership and accounting");
   end;

   declare
      Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#32#);
      Operation : Store.Theme_Operation_Access;
      Transaction : Themes.Append_Transaction (Container'Access);
   begin
      Create_Theme
        (RGBA_Theme_Description (1), Data, Operation);
      Themes.Start (Transaction, Original, Operation);
      Themes.Commit (Transaction);
      Themes.Rollback (Transaction);
      Assert
        (Themes.Count (Original) = 1
         and then Store.Byte_Count (Container) = 8,
         "committed theme append is not rolled back by cleanup");
      declare
         Suffix_Data : Terminal.App.Image_Data.Image_Data_Access :=
           new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#36#);
         Suffix : Store.Theme_Operation_Access;
         Suffix_Transaction : Themes.Append_Transaction (Container'Access);
      begin
         Create_Theme
           (RGBA_Theme_Description (2), Suffix_Data, Suffix);
         Themes.Start (Suffix_Transaction, Original, Suffix);
         Assert
           (Themes.Count (Original) = 2
            and then Store.Byte_Count (Container) = 12,
            "theme transaction appends after committed history");
         Themes.Rollback (Suffix_Transaction);
         Assert
           (Themes.Count (Original) = 1
            and then Store.Byte_Count (Container) = 8,
            "theme suffix rollback preserves committed history");
      end;
      Themes.Clear (Container, Original);
   end;

   declare
      Before_Bytes : constant Natural := Store.Byte_Count (Container);
   begin
      declare
         Data : Terminal.App.Image_Data.Image_Data_Access :=
           new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#33#);
         Operation : Store.Theme_Operation_Access;
         Transaction : Themes.Append_Transaction (Container'Access);
      begin
         Create_Theme
           (RGBA_Theme_Description (1), Data, Operation);
         Themes.Start (Transaction, Original, Operation);
         Assert
           (Themes.Count (Original) = 1,
            "uncommitted theme append is provisionally visible");
      end;
      Assert
        (Themes.Count (Original) = 0
         and then Store.Byte_Count (Container) = Before_Bytes,
         "theme append finalizer automatically rolls back");
   end;
   Store.Delete_Object (Container, Original);
end Run_Object_And_Theme_Cases;
