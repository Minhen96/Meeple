package com.meeplehearth;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

// Eager init so every bean (including repository query definitions) is validated at startup
@SpringBootTest(properties = "spring.main.lazy-initialization=false")
class MeepleBackendApplicationTests {

	@Test
	void contextLoads() {
	}

}
