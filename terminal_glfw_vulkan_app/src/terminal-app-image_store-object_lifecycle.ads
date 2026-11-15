private package Terminal.App.Image_Store.Object_Lifecycle is
   procedure Create (Object : out Image_Object_Access);
   procedure Release_Unowned (Object : in out Image_Object_Access);
   procedure Link_New
     (Container : in out Store;
      Object    : Image_Object_Access);
   procedure Link_Replacement
     (Container : in out Store;
      Object    : Image_Object_Access;
      Replaced  : Image_Object_Access);
end Terminal.App.Image_Store.Object_Lifecycle;
