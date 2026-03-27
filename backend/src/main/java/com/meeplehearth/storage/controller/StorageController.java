package com.meeplehearth.storage.controller;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

// TODO: POST /api/v1/upload/presign  — generates presigned PUT URL for Cloudflare R2 direct upload
// Client uploads directly to R2; on success, passes the R2 key back to the API (e.g. in CreatePostRequest)
@RestController
@RequestMapping("/api/v1/upload")
public class StorageController {
}
