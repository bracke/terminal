separate (Terminal.App.Image_Store_Smoke)
procedure Run_Final_Replacement_Cases is
   Container   : aliased Store.Store;
   Original    : Store.Image_Object_Access := null;
   Replacement : Store.Image_Object_Access := null;
begin
   Store.Create_Object (Original);
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
      Borrow : Store.Data_Borrow;
   begin
      Store.Borrow (Borrow, Original);
      Assert
        (Store.Borrowed_Root_Length (Borrow) > 0,
         "store ownership exposes no mutable alias for root replacement");
   end;
   Store.Create_Object (Replacement);
   Store.Link_Replacement (Container, Replacement, Original);
   declare
      Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 8 => 0);
   begin
      Install_Root
        (Container, Replacement,
         Stream_ID => Original.Stream_ID, ID => Original.ID, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 2, Pixel_Height => 1,
         Decoded_Length => 8, Row_Stride => 8, Usage_Hint => 0,
         Data => Data);
   end;
   Store.Delete_Replacement (Container, Original);
   Assert
     (Original = null
      and then Store.First (Container) = Replacement
      and then Store.Object_Count (Container) = 1
      and then Store.Byte_Count (Container) = 8,
      "replacement commit transfers the logical object count");
   Store.Delete_Object (Container, Replacement);
   Assert
     (Replacement = null
      and then Store.First (Container) = null
      and then Store.Object_Count (Container) = 0
      and then Store.Byte_Count (Container) = 0,
      "object deletion releases store accounting");
end Run_Final_Replacement_Cases;
