

  // //     /* GL objects */
  // // guint vao;
  // // guint program;
  // // guint position_index;
  // // guint color_index;

  // //   GError *error = NULL;
  // //     std::cout << "init shaders" << std::endl;

  // //   if (!init_shaders (&program,
  // //                       &position_index,
  // //                     &color_index,
  // //                     &error))
  // //     {
        
  // //       std::cout << "EROR" << std::endl;
  // //       return FALSE;
  // //     }

  // //           std::cout << "init buffers" << std::endl;


  // // /* initialize the vertex buffers */
  // // init_buffers (position_index, color_index, &vao);
  // //           std::cout << "use prog" << std::endl;

  // // GLuint texID = glGetUniformLocation(program, "myTextureSampler");

  // // // The framebuffer, which regroups 0, 1, or more textures, and 0 or 1 depth buffer.
  // // GLuint FramebufferName = 0;
  // // glGenFramebuffers(1, &FramebufferName);
  // // glBindFramebuffer(GL_FRAMEBUFFER, FramebufferName);

  // // The texture we're going to render to
  // glGenTextures(1, &self->texture_id);

  // if(self->texture_id == 0) {
  //   std::cout << "tecxtur eeror" << std::endl;
  // }


  // // "Bind" the newly created texture : all future texture functions will modify this texture
  // glBindTexture(GL_TEXTURE_2D, self->texture_id);

  // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  // glTexImage2D (GL_TEXTURE_2D, 0, GL_RGBA8, self->width, self->height, 0, GL_RGBA,
  //                 GL_UNSIGNED_BYTE, 0);


  // // // Set "renderedTexture" as our colour attachement #0
  // // glFramebufferTexture(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, self->texture_id, 0);

  // // // Set the list of draw buffers.
  // // GLenum DrawBuffers[1] = {GL_COLOR_ATTACHMENT0};
  // // glDrawBuffers(1, DrawBuffers); // "1" is the size of DrawBuffers

  // // // Always check that our framebuffer is ok
  // // if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
  // //   std::cout << "FB error" << std::endl;
  // //   return FALSE;
  // // }

  // // glBindFramebuffer(GL_FRAMEBUFFER, FramebufferName);

  // // glViewport(0,0,400,200); // Render on the whole framebuffer, complete from the lower left corner to the upper righ

  // // // Clear the screen
  // // glClearColor (0.0, 1.0, 0.5, 1.0);
  // // glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

  // // /* load our program */
  // // glUseProgram (program);

  // // // Bind our texture in Texture Unit 0
  // // glActiveTexture(GL_TEXTURE0);
  // // glBindTexture(GL_TEXTURE_2D, self->texture_id);
  // // // Set our "renderedTexture" sampler to use Texture Unit 0
  // // glUniform1i(texID, 0);

  // // /* use the buffers in the VAO */
  // // glBindVertexArray (vao);

  // // /* draw the three vertices as a triangle */
  // // glDrawArrays (GL_TRIANGLES, 0, 3);

  // // /* we finished using the buffers and program */
  // // glBindVertexArray (0);
  // // glUseProgram (0);


  // // glFlush ();


  //   // glGenTextures (1, &self->texture_id);
  //   // glBindTexture (GL_TEXTURE_2D, self->texture_id);
  //   // // further configuration here.


// /* position and color information for each vertex */
// struct vertex_info {
//   float position[3];
//   float color[3];
// };

// /* the vertex data is constant */
// static const struct vertex_info vertex_data[] = {
//   { {  0.0f,  0.500f, 0.0f }, { 1.f, 0.f, 0.f } },
//   { {  0.5f, -0.366f, 0.0f }, { 0.f, 1.f, 0.f } },
//   { { -0.5f, -0.366f, 0.0f }, { 0.f, 0.f, 1.f } },
// };

// static void
// init_buffers (guint  position_index,
//                 guint  color_index,
//               guint *vao_out)
// {
//   guint vao, buffer;

//   /* we need to create a VAO to store the other buffers */
//   glGenVertexArrays (1, &vao);
//   glBindVertexArray (vao);

//   /* this is the VBO that holds the vertex data */
//   glGenBuffers (1, &buffer);
//   glBindBuffer (GL_ARRAY_BUFFER, buffer);
//   glBufferData (GL_ARRAY_BUFFER, sizeof (vertex_data), vertex_data, GL_STATIC_DRAW);

//   /* enable and set the position attribute */
//   glEnableVertexAttribArray (position_index);
//   glVertexAttribPointer (position_index, 3, GL_FLOAT, GL_FALSE,
//                          sizeof (struct vertex_info),
//                          (GLvoid *) (G_STRUCT_OFFSET (struct vertex_info, position)));

//   /* enable and set the color attribute */
//   glEnableVertexAttribArray (color_index);
//   glVertexAttribPointer (color_index, 3, GL_FLOAT, GL_FALSE,
//                          sizeof (struct vertex_info),
//                          (GLvoid *) (G_STRUCT_OFFSET (struct vertex_info, color)));

//   /* reset the state; we will re-enable the VAO when needed */
//   glBindBuffer (GL_ARRAY_BUFFER, 0);
//   glBindVertexArray (0);

//   /* the VBO is referenced by the VAO */
//   glDeleteBuffers (1, &buffer);

//   if (vao_out != NULL)
//     *vao_out = vao;
// }

// static guint
// create_shader (int          shader_type,
//                const char  *source,
//                GError     **error,
//                guint       *shader_out)
// {
//   guint shader = glCreateShader (shader_type);
//   glShaderSource (shader, 1, &source, NULL);
//   glCompileShader (shader);

//   int status;
//   glGetShaderiv (shader, GL_COMPILE_STATUS, &status);
//   if (status == GL_FALSE)
//     {
//         std::cout << "SHADER IV ERROR" << std::endl;
//     }

//   if (shader_out != NULL)
//     *shader_out = shader;

//   return shader != 0;
// }


// static gboolean
// init_shaders (guint   *program_out,
//               guint   *position_location_out,
//               guint   *color_location_out,
//               GError **error)
// {
//  const char *vsource = R"POO(#version 330 core

// layout(location=0) in vec3 position;
// layout(location=1) in vec2 vertexUV;

// out vec2 UV;

// void main() {
//   gl_Position = vec4(position, 1.0);
//   UV = vertexUV;
// })POO";

// const char *fsource = R"POO(#version 330 core

// in vec2 UV;

// // Ouput data
// layout(location = 0) out vec3 color;

// uniform sampler2D myTextureSampler;

// void main() {
//   color = vec3(1.0,0.0,0.0);
//   // color = texture( myTextureSampler, UV ).rgb;
// })POO"; 

// // const char *vsource2 = R"POO(#version 130

// // in vec3 position;
// // in vec3 color;

// // uniform mat4 mvp;

// // smooth out vec4 vertexColor;

// // void main() {
// //   gl_Position = vec4(position, 1.0);
// //   vertexColor = vec4(color, 1.0);
// // })POO";

// // const char *fsource2 = R"POO(#version 130

// // in vec2 UV;
// // out vec3 color;

// // uniform sampler2D renderedTexture;

// // void main() {
// //   color =  texture(renderedTexture, UV.xyz);
// // })POO"; 

//   guint program = 0;
//   // guint program2 = 0;
  
//   guint vertex = 0, fragment = 0;
//   // guint vertex2 = 0, fragment2 = 0;
  
//   guint position_location = 0;
//   guint color_location = 0;

//   /* load the vertex shader */
//   create_shader (GL_VERTEX_SHADER, vsource, error, &vertex);
//   // g_bytes_unref (source);
//   if (vertex == 0) {
//     std::cout << "VERTEX ERROR" << std::endl;
//   }
    

//   /* load the fragment shader */
//   // source = g_resources_lookup_data ("/io/bassi/glarea/glarea-fragment.glsl", 0, NULL);
//   create_shader (GL_FRAGMENT_SHADER, fsource, error, &fragment);
  
//   if (fragment == 0)
//     std::cout << "FRAF ERROR" << std::endl;

//   /* link the vertex and fragment shaders together */
//   program = glCreateProgram ();

//   if(program == 0) {
//     std::cout << "PROG ZERO" << std::endl;
//   }
//   glAttachShader (program, vertex);
//   glAttachShader (program, fragment);
//   glLinkProgram (program);

//   int status = 0;
//   glGetProgramiv (program, GL_LINK_STATUS, &status);
//   if (status == GL_FALSE)
//     {
//       std::cout << "glGetProgramiv ERROR" << std::endl;
//       goto out;
//     }

//   position_location = glGetAttribLocation (program, "position");

//   /* get the location of the "position" and "color" attributes */
//   color_location = glGetAttribLocation (program, "color");

//   /* the individual shaders can be detached and destroyed */
//   glDetachShader (program, vertex);
//   glDetachShader (program, fragment);

//   // program2 = glCreateProgram();

//   // create_shader (GL_VERTEX_SHADER, vsource2, error, &vertex2);
//   // // g_bytes_unref (source);
//   // if (vertex2 == 0) {
//   //   std::cout << "VERTEX 2ERROR" << std::endl;
//   // }
//   // create_shader (GL_VERTEX_SHADER, fsource2, error, &fragment2);
//   // // g_bytes_unref (source);
//   // if (fragment2 == 0) {
//   //   std::cout << "fragment2 ERROR" << std::endl;
//   // }

//   // glAttachShader (program2, vertex2);
//   // glAttachShader (program2, fragment2);
//   // glLinkProgram (program2);

//   // status = 0;
//   // glGetProgramiv (program2, GL_LINK_STATUS, &status);
//   // if (status == GL_FALSE)
//   //   {
//   //     std::cout << "glGetProgramiv2 ERROR" << std::endl;
//   //     goto out;
//   //   }



// out:
//   if (vertex != 0)
//     glDeleteShader (vertex);
//   if (fragment != 0)
//     glDeleteShader (fragment);

//   if (program_out != NULL)
//     *program_out = program;
//   if (position_location_out != NULL)
//     *position_location_out = position_location;
//   if (color_location_out != NULL)
//     *color_location_out = color_location;

//   return program != 0;
// }


std::vector<uint8_t> raw_buffer;
    uint32_t pixels_w = 400; //w;
    uint32_t pixels_h = 200; //h;
    raw_buffer.resize(pixels_w*pixels_h * 4);
    filament::backend::PixelBufferDescriptor bd(
      raw_buffer.data(), 
      raw_buffer.size(), 
      backend::PixelDataFormat::RGBA, 
      backend::PixelDataType::UBYTE, 
       [](void* buffer, size_t size, void* capture_state) {
        uint8_t* foo = (uint8_t*)buffer;
        int32_t sum = 0;
        for(int i =0; i < size; i++) {
          sum += foo[i];
        }

        Log("SUM : %d", sum);   

        std::string path = "./out.raw";
          std::ofstream stream(path, std::ios::out | std::ios::binary);
          if(!stream.good())
          {
            std::cerr << "Failed to open: " << path << std::endl;
          }
          else {
            std::cerr << "Raw buf size " << size << std::endl;
            stream.write((char*)buffer, size);
            stream.close();
          }

     });
    render(0);
    //after rendering to the target we can now read it back
    _renderer->readPixels(_rt,0,0,pixels_w,pixels_h,std::move(bd));

    _engine->flushAndWait();

    // static void
// gl_init (PolyvoxFilamentPlugin *self)
// {
//   std::cout << "GL INIT!" << std::endl;
//   /* we need to ensure that the GdkGLContext is set before calling GL API */
//   gtk_gl_area_make_current (GTK_GL_AREA (self->gl_drawing_area));
//   gtk_gl_area_attach_buffers(GTK_GL_AREA (self->gl_drawing_area));

//   gtk_gl_area_set_has_alpha(GTK_GL_AREA (self->gl_drawing_area), TRUE);
//   gtk_gl_area_set_has_depth_buffer(GTK_GL_AREA (self->gl_drawing_area), TRUE);
//   gtk_gl_area_set_has_stencil_buffer(GTK_GL_AREA (self->gl_drawing_area), TRUE);

  
//   if(!gtk_gl_area_get_has_depth_buffer(GTK_GL_AREA (self->gl_drawing_area))) {
//     std::cout << "NO DEPTH" << std::endl;
//   }

//   if(!gtk_gl_area_get_has_stencil_buffer(GTK_GL_AREA (self->gl_drawing_area))) {
//     std::cout << "NO STENCIL" << std::endl;
//   }

//   /* if the GtkGLArea is in an error state we don't do anything */
//   if (gtk_gl_area_get_error (GTK_GL_AREA (self->gl_drawing_area)) != NULL) {
//     std::cout << "ERRIOR" << std::endl;
//     return;
//   }
//   auto ctx = gtk_gl_area_get_context (  GTK_GL_AREA(self->gl_drawing_area) );

//   // auto foo = gdk_gl_context_get_shared_context(ctx);

//   int default_id;

//   glGetIntegerv(GL_FRAMEBUFFER_BINDING, &default_id);

//   std::cout << "DEFAULT ID " << default_id << std::endl;

//   GLuint fbo = 0;
//   glGenFramebuffers(1, &fbo);
//   glBindFramebuffer(GL_FRAMEBUFFER_EXT, fbo);    


//   filament_viewer_new(
//     (void*)ctx,
//     loadResource,
//     freeResource
//   );

//     // if(!viewer) {
//     //   std::cout << "ERROR" << std::endl;
//     // }

//     // self->_viewer = viewer;

//     // create_swap_chain(self->_viewer);
    
//     // create_render_target(self->_viewer, ((FilamentTextureGL*)texture)->texture_id,400,200);


// }

struct _PolyvoxFilamentPlugin {
  GObject parent_instance;
  FlTextureRegistrar* texture_registrar;
  FlView* fl_view;

  FlTexture* texture;
  void* _viewer;
  GtkWidget* gl_drawing_area ;


  /* GL objects */
  guint vao;
  guint program;
  guint position_index;
  guint color_index;
};


//   GtkWidget *tview;
//   GtkTextBuffer *buffer;

//   tview = gtk_text_view_new ();
//   gtk_widget_show(GTK_WIDGET(tview));

//   buffer = gtk_text_view_get_buffer (GTK_TEXT_VIEW (tview));

//   gtk_text_buffer_set_text (buffer, "Hello, this is some text", -1);

//   GtkCssProvider *provider;
//   GtkStyleContext *context;
//   provider = gtk_css_provider_new ();
// gtk_css_provider_load_from_data (provider,
//                                  "textview {"
//                                  "  font: 15 serif;"
//                                  "  color: green;"
//                                  "}",
//                                  -1,
//                                  NULL);
// context = gtk_widget_get_style_context (tview);
// gtk_style_context_add_provider (context,
//                                 GTK_STYLE_PROVIDER (provider),
//                                 GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);

  // gtk_box_pack_start(box, GTK_WIDGET(tview), true, true,0);
  // gtk_widget_grab_focus(GTK_WIDGET(tview));

    GtkBox* box = GTK_BOX(gtk_box_new(GTK_ORIENTATION_VERTICAL, 1));
  gtk_widget_show(GTK_WIDGET(box));
  gtk_widget_show(GTK_WIDGET(view));

  gtk_box_pack_start(box, GTK_WIDGET(view), true, true,0);