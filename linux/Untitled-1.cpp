// static gboolean
// create_contextp (GtkGLArea *area, GdkGLContext *context)
// {
//   std::cout << "CREATE CONTEXT" << std::endl;
//   gdk_gl_context_set_debug_enabled(context, true);

//   // gtk_gl_area_make_current (area);
//   std::cout << "MADE CURENTR" << std::endl;
//   return TRUE;
// }


/* position and color information for each vertex */
struct vertex_info {
  float position[3];
  float color[3];
};

/* the vertex data is constant */
static const struct vertex_info vertex_data[] = {
  { {  0.0f,  0.500f, 0.0f }, { 1.f, 0.f, 0.f } },
  { {  0.5f, -0.366f, 0.0f }, { 0.f, 1.f, 0.f } },
  { { -0.5f, -0.366f, 0.0f }, { 0.f, 0.f, 1.f } },
};

static void
init_buffers (guint  position_index,
                guint  color_index,
              guint *vao_out)
{
  guint vao, buffer;

  /* we need to create a VAO to store the other buffers */
  glGenVertexArrays (1, &vao);
  glBindVertexArray (vao);

  /* this is the VBO that holds the vertex data */
  glGenBuffers (1, &buffer);
  glBindBuffer (GL_ARRAY_BUFFER, buffer);
  glBufferData (GL_ARRAY_BUFFER, sizeof (vertex_data), vertex_data, GL_STATIC_DRAW);

  /* enable and set the position attribute */
  glEnableVertexAttribArray (position_index);
  glVertexAttribPointer (position_index, 3, GL_FLOAT, GL_FALSE,
                         sizeof (struct vertex_info),
                         (GLvoid *) (G_STRUCT_OFFSET (struct vertex_info, position)));

  /* enable and set the color attribute */
  glEnableVertexAttribArray (color_index);
  glVertexAttribPointer (color_index, 3, GL_FLOAT, GL_FALSE,
                         sizeof (struct vertex_info),
                         (GLvoid *) (G_STRUCT_OFFSET (struct vertex_info, color)));

  /* reset the state; we will re-enable the VAO when needed */
  glBindBuffer (GL_ARRAY_BUFFER, 0);
  glBindVertexArray (0);

  /* the VBO is referenced by the VAO */
  glDeleteBuffers (1, &buffer);

  if (vao_out != NULL)
    *vao_out = vao;
}

static guint
create_shader (int          shader_type,
               const char  *source,
               GError     **error,
               guint       *shader_out)
{
  guint shader = glCreateShader (shader_type);
  glShaderSource (shader, 1, &source, NULL);
  glCompileShader (shader);

  int status;
  glGetShaderiv (shader, GL_COMPILE_STATUS, &status);
  if (status == GL_FALSE)
    {
        std::cout << "SHADER IV ERROR" << std::endl;
    }

  if (shader_out != NULL)
    *shader_out = shader;

  return shader != 0;
}

static gboolean
init_shaders (guint   *program_out,
              guint   *position_location_out,
              guint   *color_location_out,
              GError **error)
{
  const char *vsource = R"POO(#version 130

in vec3 position;
in vec3 color;

uniform mat4 mvp;

smooth out vec4 vertexColor;

void main() {
  gl_Position = vec4(position, 1.0);
  vertexColor = vec4(color, 1.0);
})POO";

const char *fsource = R"POO(#version 130

smooth in vec4 vertexColor;

out vec4 outputColor;

void main() {
  outputColor = vertexColor;
})POO"; 
  guint program = 0;
  
  guint vertex = 0, fragment = 0;
  
  guint position_location = 0;
  guint color_location = 0;

  /* load the vertex shader */
  // source = g_resources_lookup_data ("/io/bassi/glarea/glarea-vertex.glsl", 0, NULL);
  create_shader (GL_VERTEX_SHADER, vsource, error, &vertex);
  // g_bytes_unref (source);
  if (vertex == 0) {
    std::cout << "VERTEX ERROR" << std::endl;
  }
    

  /* load the fragment shader */
  // source = g_resources_lookup_data ("/io/bassi/glarea/glarea-fragment.glsl", 0, NULL);
  create_shader (GL_FRAGMENT_SHADER, fsource, error, &fragment);
  
  if (fragment == 0)
    std::cout << "FRAF ERROR" << std::endl;

  /* link the vertex and fragment shaders together */
  program = glCreateProgram ();

  if(program == 0) {
    std::cout << "PROG ZERO" << std::endl;
  }
  glAttachShader (program, vertex);
  glAttachShader (program, fragment);
  glLinkProgram (program);

  int status = 0;
  glGetProgramiv (program, GL_LINK_STATUS, &status);
  if (status == GL_FALSE)
    {
      std::cout << "glGetProgramiv ERROR" << std::endl;
      goto out;
    }

  position_location = glGetAttribLocation (program, "position");

  /* get the location of the "position" and "color" attributes */
  color_location = glGetAttribLocation (program, "color");

  /* the individual shaders can be detached and destroyed */
  glDetachShader (program, vertex);
  glDetachShader (program, fragment);

out:
  if (vertex != 0)
    glDeleteShader (vertex);
  if (fragment != 0)
    glDeleteShader (fragment);

  if (program_out != NULL)
    *program_out = program;
  if (position_location_out != NULL)
    *position_location_out = position_location;
  if (color_location_out != NULL)
    *color_location_out = color_location;

  return program != 0;
}

static void
gl_init (PolyvoxFilamentPlugin *self)
{
  
  /* we need to ensure that the GdkGLContext is set before calling GL API */
  gtk_gl_area_make_current (GTK_GL_AREA (self->gl_drawing_area));

  /* if the GtkGLArea is in an error state we don't do anything */
  if (gtk_gl_area_get_error (GTK_GL_AREA (self->gl_drawing_area)) != NULL)
    return;

  /* initialize the shaders and retrieve the program data */
  GError *error = NULL;
  if (!init_shaders (&self->program,
                      &self->position_index,
                     &self->color_index,
                     &error))
    {
      /* set the GtkGLArea in error state, so we'll see the error message
       * rendered inside the viewport
       */
      gtk_gl_area_set_error (GTK_GL_AREA (self->gl_drawing_area), error);
      g_error_free (error);
      return;
    }

  /* initialize the vertex buffers */
  init_buffers (self->position_index, self->color_index, &self->vao);

}

// static void
// gl_fini (PolyvoxFilamentPlugin *self)
// {
//   /* we need to ensure that the GdkGLContext is set before calling GL API */
//   gtk_gl_area_make_current (GTK_GL_AREA (self->gl_drawing_area));

//   /* skip everything if we're in error state */
//   if (gtk_gl_area_get_error (GTK_GL_AREA (self->gl_drawing_area)) != NULL)
//     return;

//   /* destroy all the resources we created */
//   if (self->vao != 0)
//     glDeleteVertexArrays (1, &self->vao);
//   if (self->program != 0)
//     glDeleteProgram (self->program);
// }

static void
draw_triangle (PolyvoxFilamentPlugin *self)
{
  if (self->program == 0 || self->vao == 0)
    return;

  /* load our program */
  glUseProgram (self->program);

  /* use the buffers in the VAO */
  glBindVertexArray (self->vao);

  /* draw the three vertices as a triangle */
  glDrawArrays (GL_TRIANGLES, 0, 3);

  /* we finished using the buffers and program */
  glBindVertexArray (0);
  glUseProgram (0);
}

static gboolean
gl_draw (PolyvoxFilamentPlugin *self)
{
  /* clear the viewport; the viewport is automatically resized when
   * the GtkGLArea gets a new size allocation
   */
  glClearColor (0.5, 0.5, 0.5, 1.0);
  glClear (GL_COLOR_BUFFER_BIT);

  /* draw our object */
  draw_triangle (self);

  /* flush the contents of the pipeline */
  glFlush ();

  return FALSE;
}


// static void
//   on_realize (GtkGLArea *area, PolyvoxFilamentPlugin* self)
//   {
//     std::cout << "REALIZE" << std::endl;
    
//     // GdkGLContext* context = gtk_gl_area_get_context(area); // gdk_window_create_gl_context(window, &error);

//     gtk_gl_area_make_current(area);
  

//     if(gtk_gl_area_get_error (area)) {
//       std::cout << "ERROR" << std::endl;
//     }

  
//   }

// static gboolean
// renderp (GtkGLArea *area, GdkGLContext *context)
// {

//   glClearColor (0.0f, 1.0f, 0.0f, 1.0f);
//   glClear (GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

//   GLuint vao;
//   glGenVertexArrays(1, &vao);
//   glBindVertexArray(vao);

//   GLuint texture_id = 0;
//   glGenTextures (1, &texture_id);

//   glBindTexture (GL_TEXTURE_2D, texture_id);

//   // further configuration here.

//   int len = 2000 * 2000 * 3;
//   auto buffer = new std::vector<uint8_t>(len);
//   for (int i = 0; i < len; i++)
//   {
//     if(i % 3 == 0) {
//       buffer->at(i) = (uint8_t)255;  
//     } else {
//       buffer->at(i) = (uint8_t)0;
//     }
    
//   }
//   glTexImage2D (GL_TEXTURE_2D, 0, GL_RGB8, 2000, 2000, 0, GL_RGB,
//                 GL_UNSIGNED_BYTE, buffer->data());

//   std::cout << "RENDER texture iD" << texture_id << std::endl;

//     // create_filament_texture(400, 200, self->texture_registrar);
//     glFinish();


// std::cout << "RENDER" << std::endl;
// // we completed our drawing; the draw commands will be
// // flushed at the end of the signal emission chain, and
// // the buffers will be drawn on the window
// return TRUE;
// }


    // GtkWidget *toplevel = gtk_widget_get_toplevel (GTK_WIDGET(self->fl_view));
    // if (gtk_widget_is_toplevel (toplevel))
    //  {
    //    std::cout << "TOPLEVLE" << std::endl;
    //  }
    
    // gdk_gl_context_set_debug_enabled(context, true);
        
    
    // GtkGLArea *gl_area = (GtkGLArea *) gtk_gl_area_new ();
    // gtk_widget_show(GTK_WIDGET(gl_area));
    // GtkBox* parent = GTK_BOX(gtk_widget_get_parent(GTK_WIDGET(self->fl_view)));
    // gtk_box_pack_start(parent, GTK_WIDGET(gl_area), true, true,0);
    // self->gl_drawing_area = GTK_WIDGET(gl_area);
    // GdkGLContext* context = gtk_gl_area_get_context(gl_area); 
    
    // g_signal_connect_swapped(gl_area, "realize", G_CALLBACK (gl_init), self);
    // g_signal_connect_swapped (gl_area, "render", G_CALLBACK (gl_draw), self);
    
    // g_signal_connect (gl_area, "create-context", G_CALLBACK (create_contextp), NULL);
    


  