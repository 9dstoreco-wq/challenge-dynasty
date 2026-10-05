// Resultado de una accion del servidor que el cliente puede mostrar al usuario.
//
// POR QUE: en produccion, Next.js oculta el mensaje de cualquier error LANZADO desde una accion del
// servidor (el navegador solo recibe un texto generico). Para que el usuario lea "El reto ya no esta
// abierto" en vez de un error vago, las acciones devuelven este objeto en lugar de lanzar.
export type ActionResult<T = true> = { ok: true; data: T } | { ok: false; error: string }

export function actionOk<T>(data: T): ActionResult<T> {
  return { ok: true, data }
}

export function actionError(error: string): ActionResult<never> {
  return { ok: false, error }
}
